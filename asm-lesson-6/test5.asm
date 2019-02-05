    section .text
sum:
    xorpd xmm0, xmm0
    cmp rsi, 0
    je done

next:
    addsd xmm0, [rdi]
    add rdi, 8
    dec rsi
    jnz next

done:
    ret
