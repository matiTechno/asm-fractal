    global _start
    extern printf

    section .data
format: db "factorial of 9 is %d", 0xa, 0x0

    section .text
_start:
    mov rdi, 9
    call factorial

    ;mov rdi, rax ; store return value as exit status
    ; nope we can't do this, bash is not displaying it correctly

    mov rdi, format
    mov rsi, rax
    xor rax, rax
    push rax ; align to 16 bytes; this is a convention of C on linux
             ; it seems to work without this but in some cases it might not (I heard)
    call printf

    mov rax, 60
    mov rdi, 0
    syscall

factorial:
    cmp rdi, 1
    jnbe L1  ; jump if condition is not met
    mov rax, 1
    ret

L1:
    push rdi
    dec rdi
    call factorial
    pop rdi
    imul rax, rdi
    ret
