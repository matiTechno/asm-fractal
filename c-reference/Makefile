deb:
	g++ -std=c++14 -Wall -Wextra -g -o render render.cpp -pthread

rel:
	g++ -std=c++14 -Wall -Wextra -O3 -DNDEBUG -o render render.cpp -pthread

clango3:
	clang++ -std=c++14 -Wall -Wextra -O3 -DNDEBUG -o render render.cpp -pthread

asm:
	g++ -std=c++14 -Wall -Wextra -g -S -masm=intel -o render.asm render.cpp
