; this program showcases the use of simd instructions, adding 4 floats to other 4 floats
; and printing the results
; something is not working, I need to do more research on movdqa & addps functions
; probably something is wrong with .bss alignment


global _start
extern printf

section .bss

float_buf_1 resd 4
float_buf_2 resd 4

section .data

format db "summ: %f", 0xa, 0x0

f1 dd 1.6
f2 dd 1.7
f3 dd 1.8
f4 dd 1.9
f5 dd 2.1
f6 dd 2.2
f7 dd 2.3
f8 dd 6.9

section .text
_start:
    ; with movss we know that size of the operands is dword

    ; initialize float arrays here

    movss xmm0, [f1]
    movss xmm1, [f2]
    movss xmm2, [f3]
    movss xmm3, [f4]

    movss [float_buf_1],      xmm0
    movss [float_buf_1 + 4],  xmm1
    movss [float_buf_1 + 8],  xmm2
    movss [float_buf_1 + 16], xmm3

    movss xmm0, [f5]
    movss xmm1, [f6]
    movss xmm2, [f7]
    movss xmm3, [f8]

    movss [float_buf_2],      xmm0
    movss [float_buf_2 + 4],  xmm1
    movss [float_buf_2 + 8],  xmm2
    movss [float_buf_2 + 16], xmm3

    ; perform addition

    mov rdi, float_buf_1
    mov rsi, float_buf_2
    call add_four_floats

    ; this is not necessary but it's here for clarity, printf expects float arguments
    ; in xmm* registers
    ; we only print one float result insteand of four in this example

    movss xmm0, [rdi]

    ; print
    ; why it prints 0, something is very off here

    mov rax, 1
    mov rdi, format
    call printf

    mov rax, 60
    mov rdi, 0
    syscall

; this is a C declaration of this function
; results of addition are places in buf1
; float* must be a 4 element array

; void fun(float* buf1, float* buf2);

add_four_floats:
    ;movdqa xmm0, [rdi]
    ;movdqa xmm1, [rsi]
    ;addps  xmm0, xmm1
    ;movdqa [rdi], xmm0
    movss xmm0, [rdi]
    movss xmm1, [rsi]
    addss xmm0, xmm1
    movss [rdi], xmm0
    ret
