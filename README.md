# asm-fractal
![logo](https://user-images.githubusercontent.com/20371834/52985631-0f682b80-33f5-11e9-96d2-d50e7c2db382.png)
```
$ make
nasm -g -F dwarf -f elf64 -o render.o render.asm && ld -g -o render render.o
$ ./render 8
rendering at a default resolution 1920x1080px
$ ./render  
1 or 3 arguments required - num_threads, width, height
$ ./render 8 4000 3000
$ 
```
The main thing in this repository is [render.asm](https://github.com/matiTechno/asm-fractal/blob/master/render.asm).
It is a program that renders a fractal to a PPM file with as many threads as specified in the first argument. It compiles
with nasm and runs on linux. It has no dependencies.

I tried many times to learn assembly but always failed. What finally worked for me was to do it by implementing a
concrete project that was not too easy but also not too hard. Why I decided to learn assembly?
* I was curious how to program a machine without a high-level langauge abstraction; I wanted to know how C works under the hood, how it translates to machine code; I like to understand things deeply
* it helps with performance analysis, ability to read assembly is needed when profiling code on the instruction level
* to better reason about the code - how data is really moved and transformed
* it can enable you to work in the areas like hacking, software security, reverse engineering, compilers, [ISA](https://en.wikipedia.org/wiki/Instruction_set_architecture)
* it improved my debugging skills



### Some interesting facts:
* memory allocation is done with mmap syscall
* threads are created with clone syscall
* synchronization between a main thread and render threads is done with futex syscalls
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
* 32 bit float is not enough to zoom deeply into a fractal - I went with doubles

### tools / programs I used
* gdb; gdb --args ./render 8  
some useful gdb commands:
    * continue n (n is a number; I used it to debug a rendering of a specific pixel)
    * layout asm
    * info thread
    * info reg
    * info reg rax
    * si
    * br 100
    * run
* qtcreator gdb gui; This is the best gdb gui I found on linux.  
some useful features:
    * debugger log - you can execute any gdb command you want and see the output
    * memory view
    * registers view - this is super handy
* perf record; perf report -M intel
* strace; strace -f; It helped me detect a bug that otherwise would be hard to find. I was not using futex system call correctly and a main thread was constantly invoking it instead of sleeping. It was very easy to spot in the strace output.
* htop; *shift h* hot key
* coredumpctl debug - this is how you can debug the last core dump on arch linux
* hexdump -C fractal.ppm | less; I used it to debug a PPM file and fix a bug in my program.
* compiler explorer (https://godbolt.org/)
* gcc -S -masm=intel
* man pages are great!; man -k clone; man clone; man -a clone; man 2 3 clone
* convert fractal.ppm fractal.png (ImageMagick)

### other
* *c-raw-clone* branch - I tried replacing pthread with clone in the C program but failed. Once per couple of runs the program crashes. I think it might have something to do with stack allocation and alignment? I tried using posix_memalign() but it didn't really help. I invoked clone syscall with both glibc wrapper and inline assembly. I also tried to do it with syscall(SYS_clone) but found out that it is not possible. When you create a new thread there is no return address on a stack and syscall() function has nowhere to return and crashes (not 100% sure).

* *realitme_scheduling* branch - I tried using realtime scheduling in the C program (pthread_attr_t, sched_setscheduler, sched_setaffinity). I see it working (e.g. my desktop starts to lag) but to my surprise it increased render times. Maybe I'm doing something wrong, I gave up on this.

* crashing on the sse instructions is most likely due to stack misalignment. Pushing 8 bytes onto the stack should fix the problem.

* When stepping through code with si command the program crashes on the next instruction after clone syscall. It does not happen if you place a breakpoint there and hit run (gdb version: 8.2.1).

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
* https://www.youtube.com/watch?v=rX0ItVEVjHc - Mike Acton cppcon, this is a great great talk
