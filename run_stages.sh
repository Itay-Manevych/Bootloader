#!/bin/bash
set -euo pipefail

BIN="./bin"
OBJ="./object"
EXEC="./exec"
KOBJ="./kernel"

rm -rf "$BIN" "$OBJ" "$EXEC"
mkdir -p "$BIN" "$OBJ" "$EXEC" "$KOBJ"

# -------------------------
# Fixed layout constants
# -------------------------
STAGE2_LOAD_SECTORS=64
STAGE2_BYTES=$((STAGE2_LOAD_SECTORS * 512))   # 32768 bytes
KERNEL_LBA=65                                  # stage1=0, stage2=1..64, kernel starts at 65

echo "[*] Stage2 fixed size: ${STAGE2_LOAD_SECTORS} sectors (${STAGE2_BYTES} bytes)"
echo "[*] Kernel fixed LBA:  ${KERNEL_LBA} (0x41)"

# -------------------------
# Stage 1 (boot sector)
# -------------------------
nasm -f bin boot/boot_stage1.asm -o "$BIN/stage1.bin"

STAGE1_SIZE=$(stat -c %s "$BIN/stage1.bin")
if [ "$STAGE1_SIZE" -ne 512 ]; then
  echo "Error: stage1.bin must be exactly 512 bytes (got $STAGE1_SIZE)"
  exit 1
fi

# -------------------------
# Stage 2 (ELF32 -> flat bin), loaded at 0x7E00
# -------------------------
nasm -f elf32 boot/boot_stage2.asm -o "$OBJ/stage2.o"

# headers:
# - stage2 C includes "drivers/vga/vga.h" OR "vga.h"
# safest: allow project-root includes
CINC=(-I. -Idrivers/vga -Icommon)

clang --target=i386-elf -ffreestanding -m32 \
  -fno-pic -fno-stack-protector -nostdlib "${CINC[@]}" \
  -c boot/boot_stage2_page_tables_setup.c -o "$OBJ/pt32.o"

clang --target=i386-elf -ffreestanding -m32 \
  -fno-pic -fno-stack-protector -nostdlib "${CINC[@]}" \
  -c drivers/vga/vga.c -o "$OBJ/vga32.o"

# Link stage2 to run at 0x7E00, entry is stage2_entry
ld.lld -m elf_i386 --image-base=0 -Ttext 0x7E00 -e stage2_entry \
  -o "$EXEC/stage2.elf" \
  "$OBJ/stage2.o" "$OBJ/pt32.o" "$OBJ/vga32.o"

llvm-objcopy -O binary "$EXEC/stage2.elf" "$BIN/stage2.bin"

# Enforce stage2 <= 64 sectors and pad to exactly 64 sectors
STAGE2_SIZE=$(stat -c %s "$BIN/stage2.bin")
if [ "$STAGE2_SIZE" -gt "$STAGE2_BYTES" ]; then
  echo "Error: stage2.bin is too big (${STAGE2_SIZE} bytes). Must be <= ${STAGE2_BYTES} bytes."
  exit 1
fi

PAD_BYTES=$((STAGE2_BYTES - STAGE2_SIZE))
if [ "$PAD_BYTES" -gt 0 ]; then
  dd if=/dev/zero bs=1 count="$PAD_BYTES" status=none >> "$BIN/stage2.bin"
fi
echo "[*] stage2.bin: ${STAGE2_SIZE} bytes -> padded to ${STAGE2_BYTES} bytes"

# -------------------------
# Kernel (ELF64 -> flat bin)
# Must match stage2 loader target:
# your stage2 loads kernel at segment 0x1000 offset 0 => 0x00010000
# -------------------------
KERNEL_ORG=0x00010000
KERNEL_PAD_SECTORS=64
KERNEL_PAD_BYTES=$((KERNEL_PAD_SECTORS * 512))

nasm -f elf64 kernel/kernel_entry.asm -o "$OBJ/kentry.o"

# compile kernel.c into kernel/kernel.o (as you asked)
clang --target=x86_64-elf -ffreestanding -m64 -mno-red-zone \
  -fno-pic -fno-stack-protector -nostdlib "${CINC[@]}" \
  -c kernel/kernel.c -o "$KOBJ/kernel.o"

# vga for 64-bit goes to object/ (fine)
clang --target=x86_64-elf -ffreestanding -m64 -mno-red-zone \
  -fno-pic -fno-stack-protector -nostdlib "${CINC[@]}" \
  -c drivers/vga/vga.c -o "$OBJ/vga64.o"

ld.lld -m elf_x86_64 --image-base=0 -Ttext "$KERNEL_ORG" -e kernel_entry \
  -o "$EXEC/kernel.elf" \
  "$OBJ/kentry.o" "$KOBJ/kernel.o" "$OBJ/vga64.o"

llvm-objcopy -O binary "$EXEC/kernel.elf" "$BIN/kernel.bin"

# Pad kernel to exactly 64 sectors (so stage2 can safely read 64)
KERNEL_SIZE=$(stat -c %s "$BIN/kernel.bin")
if [ "$KERNEL_SIZE" -gt "$KERNEL_PAD_BYTES" ]; then
  echo "Error: kernel.bin too big for ${KERNEL_PAD_SECTORS} sectors ($KERNEL_SIZE > $KERNEL_PAD_BYTES)"
  exit 1
fi

dd if=/dev/zero bs=1 count=$((KERNEL_PAD_BYTES - KERNEL_SIZE)) status=none >> "$BIN/kernel.bin"
echo "[*] kernel.bin: ${KERNEL_SIZE} bytes -> padded to ${KERNEL_PAD_BYTES} bytes"

# -------------------------
# Build raw image: stage1 | stage2(64 sectors padded) | kernel(64 sectors padded)
# -------------------------
cat "$BIN/stage1.bin" "$BIN/stage2.bin" "$BIN/kernel.bin" > "$BIN/os-img.bin"

IMG_SIZE=$(stat -c %s "$BIN/os-img.bin")
IMG_SECTORS=$(( (IMG_SIZE + 511) / 512 ))
echo "[*] os-img.bin: ${IMG_SIZE} bytes (${IMG_SECTORS} sectors)"

qemu-system-x86_64 -drive format=raw,file="$BIN/os-img.bin"
