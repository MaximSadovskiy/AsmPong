CC = nasm
OUT_FILE = game
COMP_FLAGS = -f bin -o $(OUT_FILE)

all: run

qemu:
	qemu-system-i386 -drive format=raw,file=$(OUT_FILE) &
qemu-debug:
	 qemu-system-i386 -S -s -drive format=raw,file=$(OUT_FILE) &
clean:
	rm -f $(OUT_FILE)
compile:
	$(CC) $(COMP_FLAGS) ./game.asm

run: clean compile qemu
debug: compile qemu-debug
	gdb -ex 'b *0x7C00' -ex 'layout asm' -ex 'target remote localhost:1234'
