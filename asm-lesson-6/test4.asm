; echo program but called from main and linked through gcc

    global main
    extern puts

    section .text
main:
    add rsi, 8
loop:
    dec rdi
    jz end

    push rdi
    push rsi

    sub rsp, 8 ; align stack to 16 bytes

    mov rdi, [rel rsi] ; rel, wrt ..plt - I don't really know what they do
                       ; but they are needed because otherwise gcc complains about
                       ; not compiling wiht -fPIC

    call puts wrt ..plt

    add rsp, 8

    pop rsi
    pop rdi

    add rsi, 8

    jmp loop
    
end:
    mov rax, 60
    mov rdi, 0
    syscall
