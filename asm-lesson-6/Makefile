1:
	nasm -f elf64 -o test.o test1.asm && ld -o test test.o -lc -dynamic-linker \
            /lib/ld-linux-x86-64.so.2

2:
	nasm -f elf64 -o test.o test2.asm && ld -o test test.o -lc -dynamic-linker \
            /lib/ld-linux-x86-64.so.2

3:
	nasm -f elf64 -g -F dwarf -o test.o test3.asm && ld -g -o test test.o

4:
	nasm -f elf64 -o test.o test4.asm && gcc -o test test.o

5:
	nasm -f elf64 -o test.o test5.asm && ld -o test test.o

6:
	nasm -f elf64 -o test.o test6.asm && ld -o test test.o -lc -dynamic-linker \
            /lib/ld-linux-x86-64.so.2

7:
	nasm -f elf64 -o test.o test7.asm && ld -o test test.o -lc -dynamic-linker \
            /lib/ld-linux-x86-64.so.2

8:
	nasm -f elf64 -o test.o test8.asm && ld -o test test.o -lc -dynamic-linker \
            /lib/ld-linux-x86-64.so.2
