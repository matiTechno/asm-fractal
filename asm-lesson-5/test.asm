section .data
    radius dq 1.7
    result dq 0

global _start

section .text

_start:
    fld qword [radius] ; put radius to st0 register
    fld qword [radius] ; put radius to st1 register
    fmul               ; multiply st0 and st1 and store it in st0

    fldpi              ; mov st0 to st1 and store pi in st0
    fmul               ; multiply st0 and st1 and store it in st0
    fstp qword [result]; mov st0 to result

    mov rax, 0
    movq xmm0, [result]

    mov rax, 60
    mov rdi, 0
    syscall
