#include <string.h>
#include <stdio.h>
#include <unistd.h>

void print(char* str, int len);

void print_from_c()
{
    printf("hello there, we are calling printf() here, good luck!\n");
}

int main()
{
    char* str = "lololo blalala\n";
    int len = strlen(str);
    print(str, len);


    char* str2 = "next, we will write something from an inlined assembly\n";
    write(1, str2, strlen(str2));

    char* str3 = "kaka buka lolo\n";
    int len_str3 = strlen(str3);

    int ret = 0;

    __asm__("movq $1, %%rax\n"
            "movq $1, %%rdi\n"
            "movq %1, %%rsi\n"
            "movl %2, %%edx\n"
            "syscall"
            : "=g" (ret)
            : "g"(str3), "g"(len_str3));

    return 0;
}
