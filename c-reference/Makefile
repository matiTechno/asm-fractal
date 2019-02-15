all:
	g++ -std=c++14 -Wall -Wextra -g -o render render.cpp

rel:
	g++ -std=c++14 -Wall -Wextra -Ofast -DNDEBUG -o render render.cpp

asm:
	g++ -std=c++14 -Wall -Wextra -g -S -masm=intel -o render.asm render.cpp
