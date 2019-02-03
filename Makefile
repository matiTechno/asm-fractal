asm:
	nasm -f elf64 -o render.o render.asm && ld -o render render.o
