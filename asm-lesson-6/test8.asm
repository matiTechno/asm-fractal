; I'm doing here something terribly wrong, I will come back to this later...
; What I want to do is to add 4 floats to 4 flats and print the results with printf()

    global _start
    extern printf

    section .bss

    float_buf_1 resd 4
    float_buf_2 resd 4

    section .data

    format db "summ: %f", 0xa, 0x0

    section .text
_start:
    mov dword [float_buf_1],      0
    mov dword [float_buf_1 + 8],  0
    mov dword [float_buf_1 + 16], 0
    mov dword [float_buf_1 + 24], 0

    mov dword [float_buf_2],      0
    mov dword [float_buf_2 + 8],  0
    mov dword [float_buf_2 + 16], 0
    mov dword [float_buf_2 + 24], 0

    mov rdi, float_buf_1
    mov rsi, float_buf_2

    call add_four_floats

   ; mov rax, 1
   ; mov rdi, format
   ; call printf

    mov rax, 60
    mov rdi, 0
    syscall

; void fun(float* buf1, float* buf2);

add_four_floats:
    movdqa xmm0, [rdi] ; it crashes on this one
    movdqa xmm1, [rsi]
    addps  xmm0, xmm1
    movdqa [rdi], xmm0
    ret
