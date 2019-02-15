deb:
	nasm -g -F dwarf -f elf64 -o render.o render.asm && ld -g -o render render.o

rel:
	nasm -f elf64 -o render.o render.asm && ld -o render render.o --strip-all
