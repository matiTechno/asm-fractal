section .bss

buffer resb 640 * 480 * 3
fd resd 1

section .data

filename db "render.ppm", 0
tmp_header db "P6 640 480 255 "
tmp_header_size dw 15

global _start

section .text
_start:

    ; todo:
    ; width and height as the arguments
    ; allocate buffer on a heap
    
    mov rax, buffer

render:
    mov byte [rax], 255
    mov byte [rax + 1], 0
    mov byte [rax + 2], 255

    add rax, 3
    cmp rax, buffer + 640 * 480 * 3
    jne render

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
    mov edx, [tmp_header_size]
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
