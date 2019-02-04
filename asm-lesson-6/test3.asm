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
    call print_one_char
    pop rax
    pop rsi

    jmp print

print_return:

    ; print new line
    mov r11, 0xa
    push r11
    call print_one_char
    pop r11

    ret

print_one_char:
    mov rax, 1
    mov rdi, 1

    add rsp, 8  ; stack now points at the function return address
                ; we move back to grab a character pushed on stack
                ; I hope my reasoning is fine here
    mov rsi, rsp
    sub rsp, 8

    mov rdx, 1
    syscall
    ret
