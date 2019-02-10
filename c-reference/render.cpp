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
        int render_width = 1920;
        int render_height = 1080;

        double left = -0.711580;
        double right = -0.711562;
        double top = 0.252133;
        double bottom = 0.252143;

        int iterations = 800;

    } const config;


    int pixel_count = config.render_width * config.render_height;
    Color* image_buf = (Color*)malloc(sizeof(Color) * pixel_count);
    assert(image_buf);

    for(int idx = 0; idx < pixel_count; ++idx)
    {
        int px_x = idx % config.render_width;
        int px_y = idx / config.render_width;

        double xcoeff = (double)px_x / (config.render_width - 1);
        double ycoeff = (double)px_y / (config.render_height - 1);

        double x0 = (1.0 - xcoeff) * config.left + xcoeff * config.right;
        double y0 = (1.0 - ycoeff) * config.top + ycoeff * config.bottom;

        int iteration = 0;
        double x = 0.0;
        double y = 0.0;

        while(x * x + y * y < 4.0 && iteration < config.iterations)
        {
            double x_temp = x * x - y * y + x0;
            y = 2.0 * x * y + y0;
            x = x_temp;
            ++iteration;
        }

        Color color;
        color.r = color.g = color.b = 255.0 * (double)iteration / config.iterations + 0.5;
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
        int bytes_written = write(fd, buf, len);
        assert(bytes_written == len);
    }

    int byte_size = sizeof(Color) * pixel_count;
    int bytes_written = write(fd, image_buf, byte_size);
    assert(bytes_written == byte_size);

    free(image_buf);
    close(fd);
    return 0;
}
