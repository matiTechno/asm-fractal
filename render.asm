; important notes:
; * higher bits of e.g rax are cleared when a value is moved in to the eax
; * sizes of the string constants are hardcoded - so be careful when changing
;   strings, I should fix this in the future, do something more robust
; * there is no error checking - both for syscalls and command line arguments

section .bss

; maybe I could store these on stack but I find it more convenient this way

current_px_idx resd 1
num_threads    resd 1
argc           resd 1
buffer         resq 1
fd             resd 1
image_width    resd 1
image_height   resd 1
string_buffer  resb 1024 ; don't change the size - one function relies on it
pthread_array  resq 128  ; pthread_t is defined as unsigned long which is 8 bytes on x64

section .data

msg_default db "rendering at a default resolution 1920x1080px", 0xa
msg_error   db "1 or 3 arguments required - num_threads, width, height", 0xa
msg_P6      db "P6 "
filename    db "fractal.ppm", 0

iterations  dd 800

view_left   dq -0.711580
view_right  dq -0.711562
view_top    dq  0.252133
view_bottom dq  0.252143

double_one    dq 1.0
double_zero   dq 0.0
double_max_u8 dq 255.0
double_half   dq 0.5
double_four   dq 4.0
double_two    dq 2.0

extern pthread_create
extern pthread_join

global _start

section .text
_start:

    ; retrive number of threads, width and height from command line arguments
    pop rax
    mov dword [argc], eax
    pop rdi ; skip argc[0] (program name)

    cmp rax, 2
    je get_thread_arg
    cmp rax, 4
    je get_thread_arg

    ; error
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_error
    mov rdx, 55
    syscall
    jmp exit

get_thread_arg:

    pop rax
    call str_to_int
    mov dword [num_threads], eax

    cmp dword [argc], 4
    je custom_resolution

    mov dword [image_width], 1920
    mov dword [image_height], 1080
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_default
    mov rdx, 46
    syscall
    jmp arg_done ; skip custom_resolution step

custom_resolution:

    pop rax ; width
    call str_to_int
    mov dword [image_width], eax
    pop rax ; height
    call str_to_int
    mov dword [image_height], eax

arg_done:

    ; allocate the image buffer with sys_mmap

    ; calculate required size
    mov eax, dword [image_width]
    mov edi, dword [image_height]
    mul edi
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

    ; without pushing 8 bytes on the stack program crashes on call pthread_create
    ; maybe it has something to do with a stack alignment
    ; I have to investigate this; it crashes on movaps instruction
    ; (inside pthread_create) which requires some alignment

    ; edit1:
    ; with 'sub rsp, 8' uncommented and 'jl create_threads', 'jl join_threads'
    ; commented program does not crash, why the hell?

    ; edit2:
    ; r9 register is overwritten by pthred_create... my mistake to not properly debug it
    ; rbx must be preserved across the call so I will use it instead of r9
    ; alternatively I could push it on the stack and pop after function call
    ; r10 is also not preserved - changing to r12

    sub rsp, 8

    mov rbx, 0 ; thread_array idx
    mov r12d, dword [num_threads]

create_threads:

    mov rax, 8 ; size of a qword
    mul rbx
    mov rdi, pthread_array
    add rdi, rax         ; pthread_t* thread

    mov rsi, 0           ; pthread_attr_t* attr
    mov rdx, thread_work ; void* start_routine
    mov rcx, 0           ; void* arg
    call pthread_create

    inc rbx
    cmp rbx, r12
    jl create_threads

    mov rbx, 0

join_threads:

    mov rdi, qword [pthread_array + rbx * 8] ; pthread_t thread
    mov rsi, 0                               ; void** retval
    call pthread_join
    inc rbx
    cmp rbx, r12
    ;jl join_threads

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

thread_work:

    mov eax, dword [image_width]
    mov edi, dword [image_height]
    mul edi
    mov r9, rax
    dec r9 ; index of the last element of image buffer

render_px:
    ; I don't use local buffer technique here because as I tested on c-reference exe
    ; setting buffer size to 1 does not decrease the performance and is equivalent to
    ; this implementation (but I don't know why it is so, what about false sharing;
    ; I plan to investigate it)

    ; this must be an atomic operation
    ; I checked how gcc __sync_fetch_and_add() looks under compiler explorer
    mov eax, 1
    lock xadd dword[current_px_idx], eax
    mov r10d, eax

    cmp r10, r9
    jge thread_work_return 

    ; setting the dividend is quite tricky
    mov edx, 0
    mov eax, r10d
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
    movsd xmm2, [double_one]
    subsd xmm2, xmm0
    movsd xmm3, [view_left]
    mulsd xmm2, xmm3
    ; xmm2 is reserved now
    movsd xmm3, xmm0
    movsd xmm4, [view_right]
    mulsd xmm3, xmm4
    addsd xmm2, xmm3
    movsd xmm0, xmm2 ; we don't need x scaling factor anymore

    ; now xmm0 contains x0

    ; note: maybe I should consider just pushing things onto the stack
    ; do the same for y0

    ; y0
    movsd xmm2, [double_one]
    subsd xmm2, xmm1
    movsd xmm3, [view_top]
    mulsd xmm2, xmm3
    movsd xmm3, xmm1
    movsd xmm4, [view_bottom]
    mulsd xmm3, xmm4
    addsd xmm2, xmm3
    movsd xmm1, xmm2

    ; now xmm1 contains y0

    mov r11d, 0              ; iteration variable
    movsd xmm2, [double_zero] ; x variable
    movsd xmm3, xmm2         ; y variable

    ; to sum up:
    ; xmm0 - x0
    ; xmm1 - y0
    ; xmm2 - x
    ; xmm3 - y
    ; r11d - iteration

    ; now execute this loop - for more see C reference program
    ; while(x * x + y * y < 4.0 && iteration < config.iterations)

loop_iter:

    movsd xmm4, xmm2
    mulsd xmm4, xmm2
    movsd xmm5, xmm3
    mulsd xmm5, xmm3
    ; values in xmm4 and xmm5 will be used soon so we don't overwrite them here
    movsd xmm6, xmm4
    addsd xmm6, xmm5
    ; xmm6 = x * x + y * y
    
    ucomisd xmm6, [double_four]
    jae end_loop_iter

    cmp r11d, dword [iterations]
    je end_loop_iter

    ; C reference code
    ; double x_temp = x * x - y * y + x0;
    ; y = 2.0 * x * y + y0;
    ; x = x_temp;

    movsd xmm6, xmm4
    subsd xmm6, xmm5
    addsd xmm6, xmm0
    ; xmm4 and xmm5 can be reused at this point, xmm6 is temp variable
    mulsd xmm3, [double_two]
    mulsd xmm3, xmm2
    addsd xmm3, xmm1
    movsd xmm2, xmm6

    inc r11d ; ++iteration
    jmp loop_iter

end_loop_iter:

    ; calculate color - iteration / iterations

    cvtsi2sd xmm0, r11d
    cvtsi2sd xmm1, [iterations]
    divsd xmm0, xmm1
    mulsd xmm0, [double_max_u8]

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
    ; note: if the result is to big to fit into the eax, higher bits are stored in edx
    mov eax, r10d
    mov edi, 3
    mul edi
    ; address
    mov rdi, [buffer]
    add rdi, rax

    mov byte [rdi]    , sil
    mov byte [rdi + 1], sil
    mov byte [rdi + 2], sil

    jmp render_px

thread_work_return:
    ret

; rax should be set to address of the target string
str_to_int:

    mov rdi, rax
    mov rsi, 10 ; multiplier
    mov rax, 0  ; we store the result here
    mov rbx, 0  ; see how we use bl - lowest byte of rbx - we zero out higher bytes

str_to_int_loop:

    cmp [rdi], byte 0
    je str_to_int_return
    mov bl, byte [rdi]
    sub bl, 48
    mul rsi
    add rax, rbx
    inc rdi
    jmp str_to_int_loop


str_to_int_return:
    ret

; arguments:
; rdi - target file descriptor
; rax - number to print
; additionally one space is printed after the number

write_int_space:

    mov rbx, 10 ; divisor
    mov r9, 0   ; length

    ; note: we are writing the number in a reverse order
    ; that's why we start at the last element of a buffer and traverse down

    mov r15, string_buffer
    add r15, 1023

    mov byte [r15], 32 ; end the string with a space
    inc r9

write_int_space_loop:

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
    jne write_int_space_loop

    mov rax, 1 ; sys_write
    ; rdi is set by the caller
    mov rsi, r15
    mov rdx, r9
    syscall

    ret
