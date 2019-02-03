section .data

    SYS_WRITE equ 1
    STD_OUT   equ 1
    SYS_EXIT  equ 60
    EXIT_CODE equ 0

    NEW_LINE   db 0xa
    WRONG_ARGC db "two arguments expected", 0xa

section .text
    global _start

_start:
    pop rcx  ; this is argc
    cmp rcx, 3
    jne argc_error

    add rsp, 8

    pop rsi
    call str_to_int
    mov r10, rax

    pop rsi
    call str_to_int
    mov r11, rax

    add r10, r11

    mov rax, r10
    xor r12, r12
    jmp int_to_str



argc_error:
    mov rax, 1
    mov rdi, 1
    mov rsi, WRONG_ARGC
    mov rdx, 23
    syscall
    jmp exit




str_to_int:
    xor rax, rax
    mov rcx, 10

next:
    cmp [rsi], byte 0
    je return_str
    mov bl, [rsi] ; why bl and not rbx?
    sub bl, 48
    mul rcx       ; multiplies rax
    add rax, rbx  ; bl is a lower 8-bits of rbx, so we add bl to rax here
    inc rsi
    jmp next

return_str:
    ret



int_to_str:
    mov rdx, 0
    mov rbx, 10
    div rbx ;    this will divide rax by rbx and put the reminder in rdx and whole part
            ;    in rax

    add rdx, 48 ; convert to ascii code
    push rdx
    inc r12 ; r12 - size of a created string
    cmp rax, 0
    jne int_to_str
    jmp print


print:
    mov rax, 1
    mul r12
    mov r12, 8
    mul r12
    mov rdx, rax

    mov rax, SYS_WRITE
    mov rdi, STD_OUT
    mov rsi, rsp

    syscall

    mov rdx, 1
    mov rsi, 10
    mov rax, SYS_WRITE
    mov rdi, STD_OUT
    syscall

    jmp exit


exit:
    mov rax, SYS_EXIT
    mov rdi, EXIT_CODE
    syscall
