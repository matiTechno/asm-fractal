# asm-fractal
![logo](https://user-images.githubusercontent.com/20371834/52985631-0f682b80-33f5-11e9-96d2-d50e7c2db382.png)
```
[mat@cs asm-fractal]$ make
nasm -g -F dwarf -f elf64 -o render.o render.asm && ld -g -o render render.o
[mat@cs asm-fractal]$ ./render 8
rendering at a default resolution 1920x1080px
[mat@cs asm-fractal]$ ./render  
1 or 3 arguments required - num_threads, width, height
[mat@cs asm-fractal]$ ./render 8 4000 3000
[mat@cs asm-fractal]$ 
```
The main thing in this repository is [render.asm](https://github.com/matiTechno/asm-fractal/blob/master/render.asm).
It is a program that renders a fractal to a ppm file with as many threads as specified in the first argument. It compiles
with nasm and runs on linux. It has no dependencies.

### Some interesting facts:
* memory allocation is done with mmap syscall
* threads are created with clone syscall
* synchronization between the main thread and render threads is done with futex syscalls
* synchronization between render threads is implemented with *lock xadd* instruction (this is how std::atomic works under
the hood)
* there are a lot of useful comments in render.asm
* I wrote the same program in C to ease the debugging of the assembly version, you can find it here
[render.cpp](https://github.com/matiTechno/asm-fractal/blob/master/c-reference/render.cpp)
* I use Makefiles to compile programs - each of them might have multiple targets (debug / release version,
compile C to asm in Intel flavor)
* I added some comments / posts here https://github.com/matiTechno/asm-fractal/issues (performance comparisons, gcc O3
image corruptions, rendered image)
* there are two other branches, I desribe them below
* C program uses lib pthread for multithreading, assembly program also used it before it got replaced with clone and futex
* you can browse through the commit history to see how this program really evolved
* command line arguments and syscalls are not error checked
* 32 bit float is not enough to zoom deeply - I went with doubles

### tools / programs I used
* gdb, gdb --args ./render 8
* qtcreator gdb gui
* perf record, perf report -M intel
* strace, strace -f
* htop
* coredumpctl debug - this is how you can debug the last core dump on arch linux
* hexdump -C fractal.ppm | less
* compiler explorer
* gcc -S -masm=intel
* man pages are great!, man -k clone, man clone, man -a clone, man 2 3 clone
* convert fractal.ppm fractal.png (ImageMagick)

### useful links / resources
* http://cs.lmu.edu/~ray/notes/nasmtutorial/ - introduction to x64 assembly
* https://github.com/0xAX/asm - another introduction, has some nice information about inline assembly in C (part 7)
* https://nullprogram.com/blog/2015/05/15/ - a post about implementing multithreading with clone syscall in x64 assembly,
it's ok but has some errros? (e.g. from what I know you cannot wait() for a CLONE_THREAD thread)
* http://www.egr.unlv.edu/~ed/assembly64.pdf - my favourite introduction to assembly, it can be also used as a
reference
* https://en.wikipedia.org/wiki/The_Linux_Programming_Interface - this is a great book, it is about linux and how in
general computers and operating systems work
* https://www.youtube.com/watch?v=nXaxk27zwlk - Chandler Carruth, does some interesting things with perf tool
* https://www.youtube.com/watch?v=fV6qYho-XVs - Matt Godbolt, also shows how to use perf tool
* https://www.cs.uaf.edu/2012/fall/cs301/lecture/11_02_other_float.html - fpu vs sse instruction sets
* http://blog.rchapman.org/posts/Linux_System_Call_Table_for_x86_64/ - best system call table I found
* https://en.wikipedia.org/wiki/False_sharing - this is an important thing when when writing multithreaded programs
(strangely I could not see it really impacting the performance of fractal renderer or raytracer project)
* https://www.youtube.com/watch?v=rX0ItVEVjHc - Mike Acton cppcon, ultimate motivation

### todo readme
* how having a clear goal or project helped me learn assembly
* why I wanted to do this project, why it might be useful to learn assembly
* provide some images of cool features of some tools
* how to debug a certain pixel - gdb continue 10000
* qtcreator gdb - debug console, memory view, picture of pixel chunk buffer under memory view with arrows pointing
to rsp, rdi, rcx (._copy_chunk)
* strace displaying human friendly names of syscall parameters
* seeing threads under htop - threads of a process (shift-h) and hardware threads
* assembly view in perf report
* gdb - layout asm, info thread, info reg, info reg rax, si
* how gdb crashes after clone syscall when stepping instruction by instruction
* explain branches - adventures with clone() and realtime scheduling
* how strace helped me understand futex syscall and fix not so obvious / visible bug
* how to enable source code debugging under gdb - nasm -F dwarf -g
* crashing on the sse instructions is most likely due to stack misialignment
