    extern atoi
    extern printf
    global _start

    section .data
error_msg : db "There are no command line arguments to avarage!", 10, 0
fmt       : db "avg: %f", 10, 0
count     : dq 0
sum       : dq 0

    section .text
_start:
    pop rdi ; argc
    dec rdi ; dont include argv[0] in count
    jz nothing_to_avg

    mov [count], rdi

    pop rsi ; argv[0] - skip, we don't need it

accumulate:

    pop rsi ; argv
    push rdi
    mov rdi, rsi
    call atoi
    pop rdi
    add [sum], rax
    dec rdi
    jnz accumulate

avarage:

    cvtsi2sd xmm0, [sum]
    cvtsi2sd xmm1, [count]
    divsd xmm0, xmm1
    mov rdi, fmt
    mov rax, 1 ; set to 1 because we are passing float argument
    call printf
    jmp exit
    

nothing_to_avg:
    mov rdi, error_msg
    xor rax, rax ; set to 0 because we are not using any float arguments
    call printf
    jmp exit

exit:
    mov rax, 60
    mov rdi, 0
    syscall
