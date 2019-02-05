1:
	nasm -f elf64 -o test.o test1.asm && ld -o test test.o -lc -dynamic-linker \
            /lib/ld-linux-x86-64.so.2

2:
	nasm -f elf64 -o test.o test2.asm && ld -o test test.o -lc -dynamic-linker \
            /lib/ld-linux-x86-64.so.2

3:
	nasm -f elf64 -o test.o test3.asm && ld -o test test.o

4:
	nasm -f elf64 -o test.o test4.asm && gcc -o test test.o
