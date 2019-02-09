#include <sys/stat.h>
#include <fcntl.h>
#include <stdlib.h>
#include <assert.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>

struct Color
{
    char r;
    char g;
    char b;
};

int main()
{
    struct
    {
        int render_width = 640;
        int render_height = 480;

        float left = -2.5f;
        float right = 1.f;
        float top = 1.f;
        float bottom = -1.f;

        int iterations = 100;

    } const config;


    int pixel_count = config.render_width * config.render_height;
    Color* image_buf = (Color*)malloc(sizeof(Color) * pixel_count);
    assert(image_buf);

    for(int idx = 0; idx < pixel_count; ++idx)
    {
        int px_x = idx % config.render_width;
        int px_y = idx / config.render_width;

        float xcoeff = (float)px_x / (config.render_width - 1);
        float ycoeff = (float)px_y / (config.render_height - 1);

        float x0 = (1.f - xcoeff) * config.left + xcoeff * config.right;
        float y0 = (1.f - ycoeff) * config.top + ycoeff * config.bottom;

        int iteration = 0;
        float x = 0.f;
        float y = 0.f;

        while(x * x + y * y < 4.f && iteration < config.iterations)
        {
            float x_temp = x * x - y * y + x0;
            y = 2.f * x * y + y0;
            x = x_temp;
            ++iteration;
        }

        Color color;
        color.r = color.g = color.b = 255.f * (float)iteration / config.iterations + 0.5f;
        image_buf[idx] = color;
    }


    int fd = open("fractal.ppm", O_WRONLY | O_TRUNC | O_CREAT,
                  S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
    assert(fd != -1);

    char buf[1024];
    {
        snprintf(buf, sizeof(buf), "P6 %d %d 255 ", config.render_width,
                 config.render_height);

        int len = strlen(buf);
        assert(write(fd, buf, len) == len);
    }

    int byte_size = sizeof(Color) * pixel_count;

    assert(write(fd, image_buf, byte_size) == byte_size);

    free(image_buf);
    close(fd);
    return 0;
}
