; program that prints command line arguments - echo

global _start
extern puts

    section .text
_start:
    pop r12    ; argc
    pop rax    ; skip argv[0];

begin:
    dec r12
    jz end

    pop rdi ; argv[...]
    call puts
    
    jmp begin

end:
    mov rax, 60
    mov rdi, 0
    syscall
