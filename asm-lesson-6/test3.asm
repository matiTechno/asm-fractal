; this is echo program

global _start

    section .text
_start:
    pop r10    ; argc
    add rsp, 8 ; skip argv[0]

loop:
    dec r10
    jz exit
    
    pop rsi ; store argv

    call print

    jmp loop

exit:
    mov rax, 60
    mov rdi, 0
    syscall

print:
    
    cmp [rsi], byte 0
    je print_return

    lodsb
    push rsi
    push rax
    jmp print_one_char

exit_print_one_char:

    pop rax
    pop rsi

    jmp print

print_return:
    ret

print_one_char:
    mov rax, 1
    mov rdi, 1
    mov rsi, rsp
    mov rdx, 1
    syscall

    jmp exit_print_one_char
