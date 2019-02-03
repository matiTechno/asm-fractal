%define WIDTH 640
%define HEIGHT 480

section .bss
    buffer: resb 3 * WIDTH * HEIGHT ; 3 bytes per pixel

section .text
    global _start



_start:

    mov r10, 0              ; current idx
    mov r11, WIDTH * HEIGHT ; number of pixels

compute:
    cmp r10, r11
    jne write_to_file

    ; write color to buffer at current index
    ; should I add or subtract from buffer?
    mov rax, r10
    mul 3
    mov r12, buffer
    add r12, rax

    ; r12 contains fist component of a pixel at current index
    mov [r12]    , 125
    mov [r12 + 1], 125
    mov [r12 + 2], 50

    inc r10
    jmp compute






write_to_file:

    ; open file
    ; write header

    mov r10, 0              ; current idx
    mov r11, WIDTH * HEIGHT ; number of pixels

write_pixel:
    cmp r10, r11
    jne end_file


    ; write pixel to file
    ; temp: we will write to stdout
    mov rax, r10
    mul 3
    mov r13, buffer
    add r13, rax

        ; red
        mov r12, 0
        mov rax, [r13]
        jmp int_to_str ; be careful with this - we don't want to overflow the stack
        jmp print

    inc r10
    jmp write_pixel

end_file:
    ; close file
    jmp exit
    




exit:
    mov rax, 60 ; exit system call
    mov rdi, 0  ; return 0
    syscall



; set rax to a target value
; r12 must be set to 0; returns the size of a created string
; rsp will point at a beginning of a string

int_to_str:
    mov rdx, 0
    mov rbx, 10
    div rbx  ; this will divide rax by rbx and put the reminder in rdx and whole part
             ;    in rax

    add rdx, 48 ; convert to ascii code
    push rdx
    inc r12     ; r12 - size of a created string
    cmp rax, 0
    jne int_to_str


print:
