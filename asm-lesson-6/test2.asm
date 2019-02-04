; program that prints command line arguments
; it crashes...
; I have no idea why
; I don't even know how to debug it...

global _start
extern puts

    section .text
_start:
    pop r10 ; argc
    pop r11 ; argv

begin:
    push rax ; align to 16 bytes

    mov rdi, [r11]
    call puts
    
    pop rax

    add r11, 8
    dec r10
    jnz begin

end:
    mov rax, 60
    mov rdi, 0
    syscall
