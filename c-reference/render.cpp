#include <sys/stat.h>
#include <fcntl.h>
#include <stdlib.h>
#include <assert.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>
#include <pthread.h>
#include <immintrin.h>

// todo, texture tiling, processing pixels spatially close to each other could improve performance

struct Config
{
    int render_width = 1920;
    int render_height = 1080;

    double left = -0.711580;
    double right = -0.711562;
    double top = 0.252133;
    double bottom = 0.252143;

    int iterations = 800;

} static _g_config;

int _g_progress = 0;
unsigned char* _g_image_buf; // one channel per color, grayscale image

#define PX_CHUNK_SIZE 64
#define SIMD_SIZE 4

void* thread_work(void*)
{
    Config config = _g_config;
    int pixel_count = config.render_width * config.render_height;
    unsigned char local_buf[PX_CHUNK_SIZE];
    assert(sizeof(local_buf) % 64 == 0); // align to cache line size
    assert(PX_CHUNK_SIZE % SIMD_SIZE == 0); // align to SIMD size
    unsigned char* image_buf = _g_image_buf;

    __m256d maxX = _mm256_set1_pd(config.render_width - 1);
    __m256d maxY = _mm256_set1_pd(config.render_height - 1);
    __m256d left = _mm256_set1_pd(config.left);
    __m256d top = _mm256_set1_pd(config.top);
    __m256d right = _mm256_set1_pd(config.right);
    __m256d bottom = _mm256_set1_pd(config.bottom);
    __m256d c1 = _mm256_set1_pd(1.0);
    __m256d c2 = _mm256_set1_pd(2.0);
    __m256d c4 = _mm256_set1_pd(4.0);
    __m256d c255 = _mm256_set1_pd(255.0);
    __m256d max_iterations = _mm256_set1_pd(config.iterations);

    while(true)
    {
        int start = __sync_fetch_and_add(&_g_progress, PX_CHUNK_SIZE);

        if(start >= pixel_count)
            break;

        for(int px_chunk_id = 0 ; px_chunk_id < PX_CHUNK_SIZE; px_chunk_id += SIMD_SIZE)
        {
            double px_x[4] __attribute__((aligned(32)));
            double px_y[4] __attribute__((aligned(32)));

            for(int i = 0; i < SIMD_SIZE; ++i)
            {
                px_x[i] = (start + px_chunk_id + i) % config.render_width;
                px_y[i] = (start + px_chunk_id + i) / config.render_width;
            }

            __m256d xcoeff = _mm256_load_pd(px_x);
            xcoeff = _mm256_div_pd(xcoeff, maxX);
            __m256d ycoeff = _mm256_load_pd(px_y);
            ycoeff = _mm256_div_pd(ycoeff, maxY);

            __m256d x0 = _mm256_sub_pd(c1, xcoeff);
            x0 = _mm256_mul_pd(x0, left);
            x0 = _mm256_fmadd_pd(xcoeff, right, x0);

            __m256d y0 = _mm256_sub_pd(c1, ycoeff);
            y0 = _mm256_mul_pd(y0, top);
            y0 = _mm256_fmadd_pd(ycoeff, bottom, y0);

            __m256d iteration = _mm256_setzero_pd();
            __m256d x = _mm256_setzero_pd();
            __m256d y = _mm256_setzero_pd();

            for(int i = 0; i < config.iterations; ++i)
            {
                // if(x*x + y*y < 4.0)
                __m256d cond = _mm256_mul_pd(x, x);
                cond = _mm256_fmadd_pd(y, y, cond);
                cond = _mm256_cmp_pd(cond, c4, _CMP_LT_OQ);
                // first 4 bytes in a mask are set to MSBits of elements in a vector, rest is set to 0
                // normally MSB of a double type is a sign bit, but previous cmp instruction set all bits in the vector to either 1 or 0
                // so movemask only makes sense here because it is used after cmp
                // in the case of simd, break only if ALL elements in the vector failed the condition
                int mask = _mm256_movemask_pd(cond);
                if(mask == 0)
                    break;

                //double x_tmp = x * x - y * y + x0;
                __m256d x_tmp = _mm256_fmadd_pd(x, x, x0);
                x_tmp = _mm256_fnmadd_pd(y, y, x_tmp);

                // y = 2.0 * x * y + y0;
                y = _mm256_mul_pd(x, y); // note, y changes
                y = _mm256_fmadd_pd(c2, y, y0);

                x = x_tmp;

                // update iteration counter only a if pixel did not escape
                // reuse x_tmp
                x_tmp = _mm256_and_pd(c1, cond);
                iteration = _mm256_add_pd(iteration, x_tmp);
            }

            // convert to u8 suitable representation
            iteration = _mm256_mul_pd(c255, iteration);
            iteration = _mm256_div_pd(iteration, max_iterations);

            double* iteration_data = (double*)&iteration;
            unsigned char* cbuf = local_buf + px_chunk_id;

            for(int i = 0; i < SIMD_SIZE; ++i)
                cbuf[i] = iteration_data[i];
        }
        memcpy(image_buf + start, local_buf, sizeof(local_buf));
    }
    return nullptr;
}

int main(int argc, const char** argv)
{
    if(argc != 2 && argc != 4)
    {
        printf("one or three arguments required - num threads, width, height\n");
        return 0;
    }

    int num_threads;
    int result = sscanf(argv[1], "%d", &num_threads);
    num_threads -= 1; // subtract main thread
    assert(result);

    if(argc ==4)
    {
        result = sscanf(argv[2], "%d", &_g_config.render_width);
        assert(result);
        result = sscanf(argv[3], "%d", &_g_config.render_height);
        assert(result);
    }
    else
        printf("rendering at the default resolution %dx%dpx\n", _g_config.render_width, _g_config.render_height);

    int pixel_count = _g_config.render_width * _g_config.render_height;

    {
        // align to chunk_size to simplify threads memcpy operation
        int alloc_size = ((pixel_count + PX_CHUNK_SIZE - 1) / PX_CHUNK_SIZE) * PX_CHUNK_SIZE;
        // align to 64 (cache line size) to avoid false sharing on writes
        int c = posix_memalign((void**)&_g_image_buf, 64, alloc_size);
        assert(!c);
        assert(_g_image_buf);
    }

    pthread_t threads[num_threads];

    for(int i = 0; i < num_threads; ++i)
    {
        int ret = pthread_create(&threads[i], nullptr, thread_work, nullptr);
        assert(!ret);
    }

    thread_work(nullptr);

    for(int i = 0; i < num_threads; ++i)
    {
        int ret = pthread_join(threads[i], nullptr);
        assert(!ret);
    }

    int fd = open("fractal.pgm", O_WRONLY | O_TRUNC | O_CREAT, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);

    assert(fd != -1);

    {
        char buf[1024];
        snprintf(buf, sizeof(buf), "P5 %d %d 255 ", _g_config.render_width, _g_config.render_height);
        int len = strlen(buf);
        int bytes_written = write(fd, buf, len);
        assert(bytes_written == len);
    }

    unsigned char* buf_out = (unsigned char*)malloc(pixel_count);

    for(int i = 0; i < pixel_count; ++i)
        buf_out[i] = _g_image_buf[i];

    int bytes_written = write(fd, buf_out, pixel_count);
    assert(bytes_written == pixel_count);
    close(fd);
    return 0;
}
