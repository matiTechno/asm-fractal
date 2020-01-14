#include <sys/stat.h>
#include <fcntl.h>
#include <stdlib.h>
#include <assert.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>
#include <pthread.h>
#include <immintrin.h>

#define TILE_WIDTH_PX 8
#define TILE_AREA_PX (TILE_WIDTH_PX * TILE_WIDTH_PX)
#define SIMD_SIZE 4
#define CACHE_LINE_SIZE 64
#define AVX_LOAD_ALIGN 32

struct Config
{
    int render_width;
    int render_height;
    double left = -0.711580;
    double right = -0.711562;
    double top = 0.252133;
    double bottom = 0.252143;
    int iterations = 800;

} static _g_config;

int _g_next_pixel;
unsigned char* _g_image_buf; // one channel per color, grayscale image

void* thread_work(void*)
{
    unsigned char tile[TILE_AREA_PX];
    assert(sizeof(tile) % CACHE_LINE_SIZE == 0);
    assert(TILE_WIDTH_PX % SIMD_SIZE == 0);
    Config config = _g_config;
    unsigned char* image_buf = _g_image_buf;
    int pixel_count = config.render_width * config.render_height;
    int tiles_per_row = config.render_width / TILE_WIDTH_PX;

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
    __m256d c0123;
    {
        assert(SIMD_SIZE == 4);
        double a[SIMD_SIZE] __attribute__((aligned(AVX_LOAD_ALIGN))) = {0.0, 1.0, 2.0, 3.0};
        c0123 = _mm256_load_pd(a);
    }

    while(true)
    {
        int buf_idx = __sync_fetch_and_add(&_g_next_pixel, TILE_AREA_PX);

        if(buf_idx >= pixel_count)
            break;

        int tile_idx = buf_idx / TILE_AREA_PX;
        int tile_px_x = (tile_idx % tiles_per_row) * TILE_WIDTH_PX;
        int tile_px_y = (tile_idx / tiles_per_row) * TILE_WIDTH_PX;

        for(int y_tile = 0; y_tile < TILE_WIDTH_PX; ++y_tile)
        {
            __m256d ycoeff = _mm256_set1_pd(tile_px_y + y_tile);
            ycoeff = _mm256_div_pd(ycoeff, maxY);

            for(int x_tile = 0; x_tile < TILE_WIDTH_PX; x_tile += SIMD_SIZE)
            {
                __m256d xcoeff = _mm256_set1_pd(tile_px_x + x_tile);
                xcoeff = _mm256_add_pd(xcoeff, c0123);
                xcoeff = _mm256_div_pd(xcoeff, maxX);

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

                // dump simd register into a local buffer
                double* iteration_data = (double*)&iteration;
                int base_idx = y_tile * TILE_WIDTH_PX + x_tile;

                for(int i = 0; i < SIMD_SIZE; ++i)
                    tile[base_idx + i] = iteration_data[i];
            }
        }
        memcpy(image_buf + buf_idx, tile, sizeof(tile));
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

    int output_width = 1920, output_height = 1080;
    int num_threads;
    int result = sscanf(argv[1], "%d", &num_threads);
    num_threads -= 1; // subtract main thread
    assert(result);

    if(argc ==4)
    {
        result = sscanf(argv[2], "%d", &output_width);
        assert(result);
        result = sscanf(argv[3], "%d", &output_height);
        assert(result);
    }
    else
        printf("rendering at the default resolution %dx%dpx\n", output_width, output_height);

    // align rendering width and heigth to a tile width
    _g_config.render_width = ((output_width + TILE_WIDTH_PX - 1) / TILE_WIDTH_PX) * TILE_WIDTH_PX;
    _g_config.render_height = ((output_height + TILE_WIDTH_PX - 1) / TILE_WIDTH_PX) * TILE_WIDTH_PX;
    {
        int size = _g_config.render_width * _g_config.render_height;
        assert(size % TILE_AREA_PX == 0); // make sure all tiles fit nicely into a buffer
        // align to cache line size to avoid false sharing on writes
        int c = posix_memalign((void**)&_g_image_buf, CACHE_LINE_SIZE, size);
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

    int output_size = output_width * output_height;
    unsigned char* buf_out = (unsigned char*)malloc(output_size);
    int tiles_per_row = _g_config.render_width / TILE_WIDTH_PX;

    // decode tiled data into a row major image format
    for(int y = 0; y < output_height; ++y)
    {
        for(int x = 0; x < output_width; ++x)
        {
            unsigned char* dst = buf_out + (y * output_width) + x;
            int tile_id = ((y / TILE_WIDTH_PX) * tiles_per_row) + (x / TILE_WIDTH_PX);
            int tile_px_id = (y % TILE_WIDTH_PX) * TILE_WIDTH_PX + x  % TILE_WIDTH_PX;
            unsigned char pixel = _g_image_buf[tile_id * TILE_AREA_PX + tile_px_id];
            *dst = pixel;
        }
    }

    int bytes_written = write(fd, buf_out, output_size);
    assert(bytes_written == output_size);
    close(fd);
    return 0;
}
