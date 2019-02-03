section .data
    msg db      "summ is correct"
    num1 equ 100
    num2 equ 66

section .text
    global _start

_start:
    mov rax, num1
    mov rbx, num2
    add rax, rbx
    call inc_rax

    push rax
    push rbx
    push rbx
    push rbx

;; get rax from stack and store in rdi
    mov rdi, [rsp + 24]

    cmp rdi , 167
    jne .exit
    jmp .correct_summ

.correct_summ:
    mov rax,     1   ; syscall number
    mov rdi,     1   ; 1st argument
    mov rsi,     msg ; 2nd argument
    mov rdx,     15  ; 3rd argument
    syscall
    jmp .exit

.exit:
    mov rax, 60
    mov rdi, 0
    syscall

inc_rax:
    inc rax
    ret
