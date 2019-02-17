#include <sys/stat.h>
#include <fcntl.h>
#include <stdlib.h>
#include <assert.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>
#include <pthread.h>
#include <sys/sysinfo.h>
#include <sched.h>

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

} static _config;

static int _progress = 0;
static Color* _image_buf;

#define PX_CHUNK_SIZE 24

void* thread_work(void*)
{
    int pixel_count = _config.render_width * _config.render_height;
    Color local_buf[PX_CHUNK_SIZE];

    while(true)
    {
        int start = __sync_fetch_and_add(&_progress, PX_CHUNK_SIZE);

        if(start >= pixel_count)
            break;

        int max_pixels_to_render = pixel_count - start;

        int pixels_to_render = PX_CHUNK_SIZE > max_pixels_to_render ? max_pixels_to_render
                               : PX_CHUNK_SIZE;

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
    if(argc != 2 && argc != 4)
    {
        printf("one or three arguments required - num threads, width, height\n");
        return 0;
    }

    int num_threads;
    int result = sscanf(argv[1], "%d", &num_threads);
    assert(result);

    bool set_affinity = false;

    // special case, enables realtime scheduling and launches as many worker threads
    // as there are cpus available (system with 4 cores and hyper-threading has 8
    // cpus)

    if(num_threads == 0)
    {
        set_affinity = true;
        num_threads = get_nprocs();

        int max_priority = sched_get_priority_max(SCHED_FIFO);

        assert(max_priority != -1);

        sched_param params;

        params.sched_priority = max_priority;

        int ret = sched_setscheduler(0, SCHED_FIFO, &params);

        // this error is very likely to happen (running this program without sudo)
        // so we exit gracefully
        if(ret == -1)
        {
            perror("sched_setscheduler()");
            return 0;
        }
    }

    if(argc ==4)
    {
        result = sscanf(argv[2], "%d", &_config.render_width);
        assert(result);

        result = sscanf(argv[3], "%d", &_config.render_height);
        assert(result);
    }
    else
    {
        printf("rendering at the default resolution %dx%dpx\n", _config.render_width,
                _config.render_height);
    }

    int pixel_count = _config.render_width * _config.render_height;
    _image_buf = (Color*)malloc(sizeof(Color) * pixel_count);
    assert(_image_buf);

    pthread_t threads[num_threads];

    for(int i = 0; i < num_threads; ++i)
    {
        // by default pthread_create inherits scheduling attributes from the parent

        int ret;

        pthread_attr_t attr;
        ret = pthread_attr_init(&attr);
        assert(!ret);

        if(set_affinity)
        {
            cpu_set_t cpu_set;
            CPU_ZERO(&cpu_set);
            CPU_SET(i, &cpu_set);
            ret = pthread_attr_setaffinity_np(&attr, sizeof(cpu_set_t), &cpu_set);
            assert(!ret);
        }

        ret = pthread_create(&threads[i], &attr, thread_work, nullptr);
        assert(!ret);

        ret = pthread_attr_destroy(&attr);
        assert(!ret);
    }

    for(int i = 0; i < num_threads; ++i)
    {
        int ret = pthread_join(threads[i], nullptr);
        assert(!ret);
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
