#include <sys/stat.h>
#include <fcntl.h>
#include <stdlib.h>
#include <assert.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>
#include <pthread.h>

struct Color
{
    char r;
    char g;
    char b;
};

struct
{
    int render_width = 1920;
    int render_height = 1080;

    double left = -0.711580;
    double right = -0.711562;
    double top = 0.252133;
    double bottom = 0.252143;

    int iterations = 800;

} static const _config;

static int _progress = 0;
static Color* _image_buf;

// This does not have any impact on performance. I would like to know why.
// What about false sharing?

#define PX_CHUNK_SIZE 36

static void* thread_work(void*)
{
    int pixel_count = _config.render_width * _config.render_height;
    Color local_buf[PX_CHUNK_SIZE];

    while(true)
    {
        int start = __sync_fetch_and_add(&_progress, PX_CHUNK_SIZE);

        if(start >= pixel_count)
            break;

        int max_pixels_to_render = pixel_count - start;

        int pixels_to_render = (PX_CHUNK_SIZE < max_pixels_to_render) ? PX_CHUNK_SIZE :
                               max_pixels_to_render;

        for(int i = 0 ; i < pixels_to_render; ++i)
        {
            int idx = start + i;

            int px_x = idx % _config.render_width;
            int px_y = idx / _config.render_width;

            double xcoeff = (double)px_x / (_config.render_width - 1);
            double ycoeff = (double)px_y / (_config.render_height - 1);

            double x0 = (1.0 - xcoeff) * _config.left + xcoeff * _config.right;
            double y0 = (1.0 - ycoeff) * _config.top + ycoeff * _config.bottom;

            int iteration = 0;
            double x = 0.0;
            double y = 0.0;

            while(x * x + y * y < 4.0 && iteration < _config.iterations)
            {
                double x_temp = x * x - y * y + x0;
                y = 2.0 * x * y + y0;
                x = x_temp;
                ++iteration;
            }

            Color color;
            color.r = color.g = color.b = 255.0 * (double)iteration / _config.iterations
                + 0.5;

            local_buf[i] = color;
        }

        memcpy(_image_buf + start, local_buf, sizeof(Color) * pixels_to_render);
    }

    return nullptr;
}

int main(int argc, const char** argv)
{
    if(argc != 2)
    {
        printf("one argument required - number of threads to run\n");
        return 0;
    }

    int pixel_count = _config.render_width * _config.render_height;
    _image_buf = (Color*)malloc(sizeof(Color) * pixel_count);
    assert(_image_buf);

    int num_threads;
    int result = sscanf(argv[1], "%d", &num_threads);
    assert(result);

    pthread_t threads[num_threads];

    for(pthread_t& thread: threads)
    {
        int r = pthread_create(&thread, nullptr, thread_work, nullptr);
        assert(!r);
    }

    for(pthread_t& thread: threads)
    {
        int r = pthread_join(thread, nullptr);
        assert(!r);
    }

    int fd = open("fractal.ppm", O_WRONLY | O_TRUNC | O_CREAT,
                  S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
    assert(fd != -1);

    char buf[1024];
    {
        snprintf(buf, sizeof(buf), "P6 %d %d 255 ", _config.render_width,
                 _config.render_height);

        int len = strlen(buf);
        int bytes_written = write(fd, buf, len);
        assert(bytes_written == len);
    }

    int byte_size = sizeof(Color) * pixel_count;
    int bytes_written = write(fd, _image_buf, byte_size);
    assert(bytes_written == byte_size);

    free(_image_buf);
    close(fd);
    return 0;
}
