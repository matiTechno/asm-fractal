deb:
	nasm -g -F dwarf -f elf64 -o render.o render.asm && ld -g -o render render.o \
            -lpthread -dynamic-linker /lib/ld-linux-x86-64.so.2 
rel:
	nasm -f elf64 -o render.o render.asm && ld -o render render.o --strip-all \
            -lpthread -dynamic-linker /lib/ld-linux-x86-64.so.2 
