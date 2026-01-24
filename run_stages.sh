#!/bin/bash

BIN="./bin/"
OBJ="./object/"
EXEC="./exec/"

STAGE_1="boot_stage1"
STAGE_2="boot_stage2"
STAGE_2_ORG="0x7E00"
STAGE_3="boot_stage3"
PADDING="padding"
OS_IMG="os-img"

rm -rf $BIN
mkdir $BIN

rm -rf $OBJ
mkdir $OBJ

rm -rf $EXEC
mkdir $EXEC

nasm -f bin "$STAGE_1.asm" -o "$BIN$STAGE_1.bin"

nasm -f elf32 "$STAGE_2.asm" -o "$OBJ$STAGE_2.o"

clang --target=i386-elf -ffreestanding -m32 -g -c "$STAGE_3.c" -o "$OBJ$STAGE_3.o"

# -Ttext 0x7E00: [ORG 0x7E00]
ld.lld -m elf_i386 --image-base=0 -Ttext $STAGE_2_ORG -o "$EXEC$STAGE_3.elf" "$OBJ$STAGE_2.o" "$OBJ$STAGE_3.o"

llvm-objcopy -O binary "$EXEC$STAGE_3.elf" "$BIN$STAGE_3.bin"

dd if=/dev/zero of="$BIN$PADDING.bin" bs=1024 count=32

# Now stage 2 and 3 are combined
cat "$BIN$STAGE_1.bin" "$BIN$STAGE_3.bin" "$BIN$PADDING.bin" > "$BIN$OS_IMG.bin"

qemu-system-x86_64 -drive format=raw,file="$BIN$OS_IMG.bin"
