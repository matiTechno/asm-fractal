section .bss

buffer resb 640 * 480 * 3
fd resd 1

section .data

filename db "fractal.ppm", 0
tmp_header db "P6 640 480 255 "
tmp_header_size dd 15

view_left   dd -2.5
view_right  dd 1.0
view_top    dd 1.0
view_bottom dd -1.0

iterations  dd 100

float_one    dd 1.0
float_zero   dd 0.0
float_max_u8 dd 255.0
float_half   dd 0.5
float_four   dd 4.0
float_two    dd 2.0

global _start

section .text
_start:

    mov r10d, 0

render_px:

    ; setting the dividend is quite tricky
    mov edx, 0
    mov eax, r10d


    mov edi, 640
    div edi

    ; edx is the x coordinate of a pixel
    ; eax is the y coordinate of a pixel

    cvtsi2ss xmm0, edx
    cvtsi2ss xmm1, eax 
    mov eax, 640
    cvtsi2ss xmm2, eax
    mov edi, 480
    cvtsi2ss xmm3, edi

    divss xmm0, xmm2
    divss xmm1, xmm3

    ; xmm0 - x range scaling factor
    ; xmm1 - y range scaling factor

    ; calculate x0 and y0 position in target range using linear interpolation

    ; x0
    movss xmm2, [float_one]
    subss xmm2, xmm0
    movss xmm3, [view_left]
    mulss xmm2, xmm3
    ; xmm2 is reserved now
    movss xmm3, xmm0
    movss xmm4, [view_right]
    mulss xmm3, xmm4
    addss xmm2, xmm3
    movss xmm0, xmm2 ; we don't need x scaling factor anymore

    ; now xmm0 contains x0

    ; note: maybe I should consider just pushing things onto the stack
    ; do the same for y0

    ; y0
    movss xmm2, [float_one]
    subss xmm2, xmm1
    movss xmm3, [view_top]
    mulss xmm2, xmm3
    movss xmm3, xmm1
    movss xmm4, [view_bottom]
    mulss xmm3, xmm4
    addss xmm2, xmm3
    movss xmm1, xmm2

    ; now xmm1 contains y0

    mov r11d, 0              ; iteration variable
    movss xmm2, [float_zero] ; x variable
    movss xmm3, xmm2         ; y variable

    ; to sum up:
    ; xmm0 - x0
    ; xmm1 - y0
    ; xmm2 - x
    ; xmm3 - y
    ; r11d - iteration

    ; now execute this loop - for more see C reference program
    ; while(x * x + y * y < 4.f && iteration < config.iterations)

loop_iter:

    movss xmm4, xmm2
    mulss xmm4, xmm2
    movss xmm5, xmm3
    mulss xmm5, xmm3
    ; values in xmm4 and xmm5 will be used soon so we don't overwrite them here
    movss xmm6, xmm4
    addss xmm6, xmm5
    ; xmm6 = x * x + y * y
    
    ucomiss xmm6, [float_four]
    jae end_loop_iter

    cmp r11d, dword [iterations]
    je end_loop_iter

    ; C reference code
    ; float x_temp = x * x - y * y + x0;
    ; y = 2.f * x * y + y0;
    ; x = x_temp;

    movss xmm6, xmm4
    subss xmm6, xmm5
    addss xmm6, xmm0
    ; xmm4 and xmm5 can be reused at this point, xmm6 is temp variable
    mulss xmm3, [float_two]
    mulss xmm3, xmm3
    mulss xmm3, xmm2
    addss xmm3, xmm1
    movss xmm2, xmm6

    inc r11d ; ++iteration
    jmp loop_iter

end_loop_iter:

    ; calculate color - iteration / iterations

    cvtsi2ss xmm0, r11d
    cvtsi2ss xmm1, [iterations]
    divss xmm0, xmm1
    mulss xmm0, [float_max_u8]
    addss xmm0, [float_half]
    cvtss2si eax, xmm0

    mov byte [buffer + r10 * 3]    , al
    mov byte [buffer + r10 * 3 + 1], al
    mov byte [buffer + r10 * 3 + 2], al

    inc r10d
    cmp r10d, 640 * 480
    jne render_px

    ; open file
    mov rax, 2
    mov rdi, filename
    mov rsi, 1101o ; truncate, create, write only
    mov rdx, 644o  ; mode (permissions)
    syscall

    mov [fd], eax ; save the file descriptor

    ; write to file - header
    mov rax, 1
    mov edi, dword [fd]
    mov rsi, tmp_header
    ; high 32 bits of rax are cleard to 0, there is not movzx for dword
    mov edx, dword [tmp_header_size]
    syscall

    ; write to file - buffer
    mov rax, 1
    mov edi, dword [fd]
    mov rsi, buffer
    mov rdx, 640 * 480 * 3
    syscall

    ; close file
    mov rax, 3
    mov edi, dword [fd]
    syscall
    
    ; exit
    mov rax, 60
    mov rdi, 0
    syscall
