common = -mfma -Wall -Wextra -pthread -fno-exceptions -fno-rtti render.cpp
rel = -O3 -DNDEBUG

debug:
	g++ $(common) -g -o render

rel:
	g++ $(common) $(rel) -o render

clang_rel:
	clang++ $(common) $(rel) -o render

asm:
	g++ $(common) $(rel)  -S -masm=intel -o render.asm
