; important notes:
; * higher bits of rax are cleared when a value is moved in to the eax (this also applies
;       to other registers)
; * sizes of the string constants are hardcoded
; * there is no error checking, both for syscalls and command line arguments

%define STACK_SIZE    1024
%define PX_CHUNK_SIZE 24 ; 3 * PX_CHUNK_SIZE must be multiple of 8
%define ITERATIONS    800
%define DP_ITERATIONS  __float64__(800.0)
%define DP_VIEW_LEFT   __float64__(-0.711580)
%define DP_VIEW_RIGHT  __float64__(-0.711562)
%define DP_VIEW_TOP    __float64__(-0.252133)
%define DP_VIEW_BOTTOM __float64__(-0.252143)

section .bss

; maybe I could store these on stack but I find it more convenient this way
; bss is initialized to 0

futex          resd 1
current_px_idx resd 1
pixel_count    resd 1
num_threads    resd 1
argc           resd 1
fd             resd 1
image_width    resd 1
image_height   resd 1
string_buffer  resb 1024 ; don't change the size - one function relies on it
buffer         resq 1

section .data

msg_default db "rendering at a default resolution 1920x1080px", 0xa
msg_error   db "1 or 3 arguments required - num_threads, width, height", 0xa
msg_P6      db "P6 "
filename    db "fractal.ppm", 0

section .text

global _start

_start:
    ; retrive number of threads, width and height from command line arguments
    pop rax
    mov dword [argc], eax
    pop rdi ; skip argc[0] (program name)

    cmp rax, 2
    je .get_thread_arg
    cmp rax, 4
    je .get_thread_arg

    ; error
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_error
    mov rdx, 55
    syscall
    jmp exit

.get_thread_arg:

    pop rax
    call str_to_int
    mov dword [num_threads], eax

    cmp dword [argc], 4
    je .custom_resolution

    mov dword [image_width], 1920
    mov dword [image_height], 1080
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_default
    mov rdx, 46
    syscall
    jmp .arg_done ; skip .custom_resolution step

.custom_resolution:

    pop rax ; width
    call str_to_int
    mov dword [image_width], eax
    pop rax ; height
    call str_to_int
    mov dword [image_height], eax

.arg_done:

    ; allocate the image buffer with mmap

    ; calculate required size
    mov eax, dword [image_width]
    mov edi, dword [image_height]
    mul edi
    mov dword [pixel_count], eax ; store this value - we will use it later
    mov edi, 3
    mul edi
    mov esi, eax ; store the results in rsi

    mov rax, 9
    mov rdi, 0 ; address - null
    ; rsi is already set - size
    mov rdx, 0x3 ; permission - read | write
    mov r10, 0x22 ; flags - private | anonymous
    mov r8, -1 ; fd - must be -1 when anonymous flag is set
    mov r9, 0 ; offset - must be 0 when anonymous flag is set
    syscall
    mov qword [buffer], rax ; store the address returned by sys_mmap

    mov r12d, dword [num_threads]
    mov rbx, 0 ; iterator

.create_threads:

    ; mmap - allocate thread stack
    mov rax, 9
    mov rdi, 0
    mov rsi, STACK_SIZE
    mov rdx, 0x3
    mov r10, 0x22
    mov r8, -1
    mov r9, 0
    syscall

    mov rsi, rax
    ; stack grows downwards so we point to the highest possible address of the allocated
    ; memory
    add rsi, STACK_SIZE

    mov rax, 56 ; clone
    mov rdi, 10900h ; CLONE_THREAD | CLONE_VM | CLONE_SIGHAND
    ; rsi is already set - stack pointer
    syscall

    ; child thread path
    cmp rax, 0
    je thread_work

    inc rbx
    cmp rbx, r12
    jl .create_threads

    ; wait for child threads to end, implemented with futex syscall
    mov rax, 202
    mov rdi, futex
    mov rsi, 128 ; FUTEX_PRIVATE_FLAG | FUTEX_WAIT
    ; if *futex and this value are different - syscall returns immediately
    ; this is useful if the threads would terminate before this syscall is issued
    mov rdx, 0   
    mov r10, 0   ; timespec* timeout
    syscall

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
    mov rsi, msg_P6
    mov rdx, 3
    syscall

    mov eax, dword [image_width]
    call write_int_space
    mov eax, dword [image_height]
    call write_int_space
    mov eax, 255
    call write_int_space

    ; write to file - buffer
    ; calculate byte size
    mov eax, dword [image_width]
    mov edi, dword [image_height]
    mul edi
    mov edi, 3
    mul edi
    mov edx, eax

    mov rax, 1
    mov edi, dword [fd]
    mov rsi, [buffer]
    ; rdx is already set
    syscall

    ; close file
    mov rax, 3
    mov edi, dword [fd]
    syscall
    
exit:
    mov rax, 60
    mov rdi, 0
    syscall

; note: we can't return from this function - there is nowhere to return
; syscall exit is called to terminate (jmp is used to enter this function, not call)

thread_work:

    ; we use stack to store the chunk, rsp will point to the start of the chunk buffer
    ; rbp to the end of it
    mov rbp, rsp
    sub rsp, PX_CHUNK_SIZE * 3

    mov r9d, dword [pixel_count]
    xor r13, r13 ; if 1 this thread will wake main thread

.render_chunk:

    ; this must be an atomic operation
    ; I checked how gcc __sync_fetch_and_add() looks under compiler explorer
    ; I checked how program behaves without this atomicity and there are corruptions,
    ; small black dots across the image

    mov eax, PX_CHUNK_SIZE
    lock xadd dword[current_px_idx], eax
    cmp rax, r9
    jge .thread_exit
    mov r15, rax ; save the index

    mov rax, r9
    sub rax, r15
    ; rax contains the number of pixels left to render

    xor r10, r10 ; iterator

    cmp rax, PX_CHUNK_SIZE
    jle .last_chunk

    mov r14, PX_CHUNK_SIZE ; how many pixels we have to render
    jmp .render_px ; skip .last_chunk

.last_chunk:

    mov r14, rax
    mov r13, 1

    ; to sum up:
    ; r9  - number of pixels of the image
    ; r13 - if 1 wake the main thread on exit
    ; r15 - index at which chunk is copied to the buffer
    ; r10 - iterator (iterate over pixels in the chunk)
    ; r14 - number of pixels we have to render

.render_px:

    ; setting the dividend is quite tricky
    mov edx, 0
    mov eax, r15d
    add eax, r10d
    mov edi, dword [image_width]
    div edi

    ; edx is the x coordinate of a pixel
    ; eax is the y coordinate of a pixel

    cvtsi2sd xmm0, edx
    cvtsi2sd xmm1, eax 
    mov eax, dword [image_width]
    cvtsi2sd xmm2, eax
    mov edi, [image_height]
    cvtsi2sd xmm3, edi

    divsd xmm0, xmm2
    divsd xmm1, xmm3

    ; xmm0 - x range scaling factor
    ; xmm1 - y range scaling factor

    ; calculate x0 and y0 position in target range using linear interpolation

    ; x0
    mov rbx, __float64__(1.0) ; rbx is reserved
    movq xmm2, rbx
    subsd xmm2, xmm0
    mov rax, DP_VIEW_LEFT
    movq xmm3, rax
    mulsd xmm2, xmm3
    ; xmm2 is reserved now
    movsd xmm3, xmm0
    mov rax, DP_VIEW_RIGHT
    movq xmm4, rax
    mulsd xmm3, xmm4
    addsd xmm2, xmm3
    movsd xmm0, xmm2 ; we don't need x scaling factor anymore

    ; now xmm0 contains x0
    ; do the same for y0

    ; y0
    movq xmm2, rbx ; rbx can be reused
    subsd xmm2, xmm1
    mov rax, DP_VIEW_TOP
    movq xmm3, rax
    mulsd xmm2, xmm3
    movsd xmm3, xmm1
    mov rax, DP_VIEW_BOTTOM
    movq xmm4, rax
    mulsd xmm3, xmm4
    addsd xmm2, xmm3
    movsd xmm1, xmm2

    ; now xmm1 contains y0

    mov r11d, 0      ; iteration variable
    xorps xmm2, xmm2 ; x variable, zero
    movsd xmm3, xmm2 ; y variable

    ; to sum up:
    ; xmm0 - x0
    ; xmm1 - y0
    ; xmm2 - x
    ; xmm3 - y
    ; r11d - iteration

    ; now execute this loop - for more see C reference program
    ; while(x * x + y * y < 4.0 && iteration < config.iterations)

.escape_px:

    movsd xmm4, xmm2
    mulsd xmm4, xmm2
    movsd xmm5, xmm3
    mulsd xmm5, xmm3
    ; values in xmm4 and xmm5 will be used soon so we don't overwrite them here
    movsd xmm6, xmm4
    addsd xmm6, xmm5
    ; xmm6 = x * x + y * y
    
    mov rax, __float64__(4.0)
    movq xmm7, rax
    ucomisd xmm6, xmm7
    jae .done_escape_px

    cmp r11d, ITERATIONS
    je .done_escape_px

    ; C reference code
    ; double x_temp = x * x - y * y + x0;
    ; y = 2.0 * x * y + y0;
    ; x = x_temp;

    movsd xmm6, xmm4
    subsd xmm6, xmm5
    addsd xmm6, xmm0
    ; xmm4 and xmm5 can be reused at this point, xmm6 is temp variable
    mov rax, __float64__(2.0)
    movq xmm4, rax
    mulsd xmm3, xmm4
    mulsd xmm3, xmm2
    addsd xmm3, xmm1
    movsd xmm2, xmm6

    inc r11d ; ++iteration
    jmp .escape_px

.done_escape_px:

    ; calculate color - iteration / iterations

    cvtsi2sd xmm0, r11d
    mov rax, DP_ITERATIONS
    movq xmm1, rax
    divsd xmm0, xmm1
    mov rax, __float64__(255.0)
    movq xmm1, rax
    mulsd xmm0, xmm1

    ; oh man, what a bug - cvtss2si is performing rounding so we don't have to
    ; add 0.5 to the color value - if we do this when color == 255 we overflow and
    ; actually invert the color
    ; commenting out this instruction
    ; I'm glad I did c-reference version to compare the intermediate results,
    ; without this I don't know if I would complete this program.
    ; (I did not debug the C program disassembly, just inspected variables and compared
    ; with registers in this program)

    ;addss xmm0, [float_half]
    
    ; edit (10 February 2019): changed cvtss2si to cvtsd2si

    cvtsd2si esi, xmm0

    ; calculate the address of the pixel

    ; offset
    ; note: if the result is too big to fit into the eax, higher bits are stored in edx
    ; (it is not the case here)
    mov eax, r10d
    mov edi, 3
    mul edi
    ; address
    mov rdi, rsp
    add rdi, rax

    mov byte [rdi]    , sil
    mov byte [rdi + 1], sil
    mov byte [rdi + 2], sil

    inc r10
    cmp r10, r14
    jne .render_px

    mov rdi, rsp ; start of the chunk buffer

    mov eax, r15d
    mov edx, 3
    mul edx
    mov rdx, [buffer]
    add rdx, rax ; location we copy pixels to

.copy_chunk:

    mov rsi, [rdi] ; 8 bytes of data we want to copy to buffer
    mov [rdx], rsi ; copy!

    add rdi, 8
    add rdx, 8
    cmp rdi, rbp
    jne .copy_chunk

    jmp .render_chunk

.thread_exit:
    
    cmp r13, 1
    jne exit

    ; futex, only the thread that rendered the last pixel will wake the main thread
    inc dword [futex]
    mov rax, 202
    mov rdi, futex
    mov rsi, 129 ; FUTEX_PRIVATE_FLAG | FUTEX_WAKE
    mov rdx, 1 ; number of waiters to wake
    syscall

    jmp exit

; rax should be set to address of the target string
str_to_int:

    mov rdi, rax
    mov rsi, 10 ; multiplier
    mov rax, 0  ; we store the result here
    mov rbx, 0  ; see how we use bl - lowest byte of rbx - we zero out higher bytes

.loop:

    cmp [rdi], byte 0
    je .return
    mov bl, byte [rdi]
    sub bl, 48
    mul rsi
    add rax, rbx
    inc rdi
    jmp .loop


.return:
    ret

; arguments:
; rdi - target file descriptor
; rax - number to print
; additionally one space is printed after the number

write_int_space:

    mov rbx, 10 ; divisor
    mov r9, 0   ; length

    ; note: we are wmulsd raxriting the number in a reverse order
    ; that's why we start at the last element of a buffer and traverse down

    mov r15, string_buffer
    add r15, 1023

    mov byte [r15], 32 ; end the string with a space
    inc r9

.loop:

    ; higher 8 bytes of the dividend are stored in rdx - we set it to 0
    ; (our dividend fits into rax and does not need to be extended to rdx)

    mov rdx, 0 

    ; lower 8 bytes are stored in rax and it is already set correctly by the caller

    div rbx ; whole part - rax, reminder - rdx
    add rdx, 48 ; convert to ascii
    dec r15
    mov byte [r15], dl ; write a character to a temporary buffer
    inc r9
    cmp rax, 0
    jne .loop

    mov rax, 1 ; sys_write
    ; rdi is set by the caller
    mov rsi, r15
    mov rdx, r9
    syscall

    ret
