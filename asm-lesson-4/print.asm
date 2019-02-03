global print

extern print_from_c

section .text
print:
    mov r10, rdi
    mov r11, rsi
    
    mov rax, 1
    mov rdi, 1
    mov rsi, r10
    mov rdx, r11
    syscall

    call print_from_c

    ret
