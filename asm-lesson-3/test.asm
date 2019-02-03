section .data
    
    input_string db "Hello World!"

section .bss
    
    output_string resb 13 ; len(input_string)

section .text
    global _start

_start:
    
    mov rsi, input_string
    mov rcx, 0
    cld     ; I don't understand this fully
    mov rdi, $ + 15 ; I don't understand this fully
    call strlen
    mov rax, 0
    mov rdi, 0
    jmp reverse_str

strlen:
    
    cmp byte [rsi], 0
    je exit_from_function
    lodsb
    push rax ; it pushes 4 bytes or what? we need to push only 1 byte
    inc rcx
    jmp strlen

exit_from_function:
    push rdi
    ret

reverse_str:
    cmp rcx, 0
    je print_result
    pop rax
    mov [output_string + rdi], rax
    dec rcx
    inc rdi
    jmp reverse_str

print_result:
    mov rdx, rdi
    mov rax, 1
    mov rdi, 1
    mov rsi, output_string
    syscall
    jmp print_new_line

print_new_line: ; I don't know why but it does not work
    mov rdx, 1
    mov rsi, 10
    mov rax, 1
    mov rdi, 1
    syscall
    jmp exit

exit:
    mov rax, 60
    mov rdi, 0
    syscall
