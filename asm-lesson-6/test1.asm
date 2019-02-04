; this is a fibonacci print program

global _start
extern printf

format:
    db "%20ld", 10, 0

    section .text
_start:
    mov rcx, 90
    xor rax, rax
    xor rbx, rbx
    inc rbx

print:
    push rax
    push rcx
    sub rsp, 8 ; align stack pointer to 16-byte boundary
               ; remember that call pushes 8 bytes for the return address

    mov rdi, format
    mov rsi, rax
    xor rax, rax ; why this? there is a crash without it
                 ; ok, it tells C that we are not passing anything in floating-point
                 ; registers (xmm0, ...)

    call printf

    pop rcx ; pop dummy alignment
    pop rcx
    pop rax

    mov rdx, rax
    mov rax, rbx
    add rbx, rdx

    dec rcx
    jnz print

    mov rax, 60
    mov rdi, 0
    syscall
