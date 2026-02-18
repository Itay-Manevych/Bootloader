#!/bin/bash
# quit instantly when failing
set -euo pipefail

# -------------------------
# Output layout (generated)
# -------------------------
BUILD="./build"

B16="$BUILD/16-bit"
B32="$BUILD/32-bit"
B64="$BUILD/64-bit"
IMG="$BUILD/image"

OBJ32="$B32/obj"
ELF32="$B32/elf"
BIN32="$B32/bin"

OBJ64="$B64/obj"
ELF64="$B64/elf"
BIN64="$B64/bin"

BIN16="$B16/bin"

echo "[*] Cleaning up the previous build..."

rm -rf "$BUILD"

echo "[*] Creating new build..."
mkdir -p "$BIN16" "$OBJ32" "$ELF32" "$BIN32" "$OBJ64" "$ELF64" "$BIN64" "$IMG"

# -------------------------
# Fixed disk layout
# -------------------------
# stage1 = sector 0
# stage2 = sectors 1..64  (64 sectors)
# kernel = starts at 65    (0x41)
STAGE2_SECTORS=64
STAGE2_BYTES=$((STAGE2_SECTORS * 512))

# stage2 loads kernel to segment 0x1000:0x0000 -> 0x1000* 16 + 0 = 0x10000
KERNEL_LOAD_ADDRESS=0x00010000
KERNEL_SECTORS=64
KERNEL_BYTES=$((KERNEL_SECTORS * 512))

# -------------------------
# Include paths for C files
# -------------------------
# vga.c uses: #include "drivers/vga/vga.h"
# so include project root (.) so "drivers/..." resolves.
CINC=(-I.)

# ----------------------------
# Stage 1 (16-bit boot sector)
# ----------------------------
echo "[*] Assembling stage1 (boot sector) to raw binary"
nasm -f bin boot/boot_stage1.asm -o "$BIN16/stage1.bin"

STAGE1_SIZE=$(stat -c %s "$BIN16/stage1.bin")
if [ "$STAGE1_SIZE" -ne 512 ]; then
  echo "Error: stage1.bin must be exactly 512 bytes (got $STAGE1_SIZE)"
  exit 1
fi
echo "[*] stage1.bin: ${STAGE1_SIZE} bytes"

# ---------------------------
# Stage 2 (ELF32 -> flat bin)
# ---------------------------
echo "[*] Assembling stage2 into 32-bit object"
nasm -f elf32 boot/boot_stage2.asm -o "$OBJ32/boot_stage2.o"

echo "[*] Compiling mpaland printf into 32-bit freestanding object"
clang --target=i386-elf -ffreestanding -m32 \
  -fno-pic -fno-stack-protector -fno-builtin -nostdlib "${CINC[@]}" \
  -DPRINTF_DISABLE_SUPPORT_LONG_LONG \
  -c common/third-party/mpaland/printf.c \
  -o "$OBJ32/mpaland_printf32.o"

echo "[*] Compiling mpaland _putchar (Console) into 32-bit freestanding object"
clang --target=i386-elf -ffreestanding -m32 \
  -fno-pic -fno-stack-protector -fno-builtin -nostdlib "${CINC[@]}" \
  -c common/third-party/mpaland/putchar_console.c \
  -o "$OBJ32/mpaland_putchar32.o"

echo "[*] Compiling console into 32-bit freestanding object"
clang --target=i386-elf -ffreestanding -m32 \
  -fno-pic -fno-stack-protector -fno-builtin -nostdlib "${CINC[@]}" \
  -c common/console/console.c \
  -o "$OBJ32/console32.o"

echo "[*] Compiling the vga driver into 32-bit freestanding object"
clang --target=i386-elf -ffreestanding -m32 \
  -fno-pic -fno-stack-protector -nostdlib "${CINC[@]}" \
  -c drivers/vga/vga.c \
  -o "$OBJ32/vga32.o"

echo "[*] Compiling vga-sink into 32-bit freestanding object"
clang --target=i386-elf -ffreestanding -m32 \
  -fno-pic -fno-stack-protector -fno-builtin -nostdlib "${CINC[@]}" \
  -c drivers/vga/vga-sink/vga-sink.c \
  -o "$OBJ32/vga_sink32.o"


echo "[*] Compiling page setup helper into 32-bit freestanding object"
clang --target=i386-elf -ffreestanding -m32 \
  -fno-pic -fno-stack-protector -nostdlib "${CINC[@]}" \
  -c boot/boot_stage2_page_tables_setup.c \
  -o "$OBJ32/boot_stage2_page_tables_setup.o"


echo "[*] Linking stage2 object, helper and vga driver into 32-bit ELF"
ld.lld -m elf_i386 --image-base=0 -Ttext 0x7E00 -e stage2_entry \
  -o "$ELF32/stage2.elf" \
  "$OBJ32/boot_stage2.o" \
  "$OBJ32/boot_stage2_page_tables_setup.o" \
  "$OBJ32/mpaland_printf32.o" \
  "$OBJ32/mpaland_putchar32.o" \
  "$OBJ32/vga32.o" \
  "$OBJ32/vga_sink32.o" \
  "$OBJ32/console32.o"

echo "[*] Converting the stage2 32-bit ELF into raw binary file"
llvm-objcopy -O binary "$ELF32/stage2.elf" "$BIN32/stage2.bin"

STAGE2_SIZE=$(stat -c %s "$BIN32/stage2.bin")
if [ "$STAGE2_SIZE" -gt "$STAGE2_BYTES" ]; then
  echo "Error: stage2.bin too big (${STAGE2_SIZE} bytes). Must be <= ${STAGE2_BYTES} bytes."
  exit 1
fi

echo "[*] Padding the stage2 binary to fit ${STAGE2_SECTORS} sectors"
PAD_BYTES=$((STAGE2_BYTES - STAGE2_SIZE))
if [ "$PAD_BYTES" -gt 0 ]; then
  dd if=/dev/zero bs=1 count="$PAD_BYTES" status=none >> "$BIN32/stage2.bin"
fi
echo "[*] stage2.bin: ${STAGE2_SIZE} bytes -> padded to ${STAGE2_BYTES} bytes"

# -------------------------
# Kernel (ELF64 -> flat bin)
# -------------------------
echo "[*] Assembling the kernel entry stub"
nasm -f elf64 kernel/kernel_entry.asm -o "$OBJ64/kernel_entry.o"

echo "[*] Compiling mpaland printf into 64-bit freestanding object"
clang --target=x86_64-elf -ffreestanding -m64 -mno-red-zone \
  -fno-pic -fno-stack-protector -fno-builtin -nostdlib "${CINC[@]}" \
  -c common/third-party/mpaland/printf.c \
  -o "$OBJ64/mpaland_printf64.o"

echo "[*] Compiling mpaland _putchar (Console) into 64-bit freestanding object"
clang --target=x86_64-elf -ffreestanding -m64 -mno-red-zone \
  -fno-pic -fno-stack-protector -fno-builtin -nostdlib "${CINC[@]}" \
  -c common/third-party/mpaland/putchar_console.c \
  -o "$OBJ64/mpaland_putchar64.o"

echo "[*] Compiling console into 64-bit freestanding object"
clang --target=x86_64-elf -ffreestanding -m64 -mno-red-zone \
  -fno-pic -fno-stack-protector -fno-builtin -nostdlib "${CINC[@]}" \
  -c common/console/console.c \
  -o "$OBJ64/console64.o"

echo "[*] Compiling the vga driver into 64-bit freestanding object"
clang --target=x86_64-elf -ffreestanding -m64 -mno-red-zone \
  -fno-pic -fno-stack-protector -nostdlib "${CINC[@]}" \
  -c drivers/vga/vga.c \
  -o "$OBJ64/vga64.o"

echo "[*] Compiling vga-sink into 64-bit freestanding object"
clang --target=x86_64-elf -ffreestanding -m64 -mno-red-zone \
  -fno-pic -fno-stack-protector -fno-builtin -nostdlib "${CINC[@]}" \
  -c drivers/vga/vga-sink/vga-sink.c \
  -o "$OBJ64/vga_sink64.o"

echo "[*] Compiling the kernel.c into 64-bit freestanding object"
clang --target=x86_64-elf -ffreestanding -m64 -mno-red-zone \
  -fno-pic -fno-stack-protector -nostdlib "${CINC[@]}" \
  -c kernel/kernel.c \
  -o "$OBJ64/kernel.o"


echo "[*] Linking kernel entry, kernel object and vga driver into 64-bit ELF"
ld.lld -m elf_x86_64 --image-base=0 -Ttext "$KERNEL_LOAD_ADDRESS" -e kernel_entry \
  -o "$ELF64/kernel.elf" \
  "$OBJ64/kernel.o" \
  "$OBJ64/kernel_entry.o" \
  "$OBJ64/mpaland_printf64.o" \
  "$OBJ64/mpaland_putchar64.o" \
  "$OBJ64/vga64.o" \
  "$OBJ64/vga_sink64.o" \
  "$OBJ64/console64.o"

echo "[*] Converting the kernel 64-bit ELF into raw binary file"
llvm-objcopy -O binary "$ELF64/kernel.elf" "$BIN64/kernel.bin"

KERNEL_SIZE=$(stat -c %s "$BIN64/kernel.bin")
if [ "$KERNEL_SIZE" -gt "$KERNEL_BYTES" ]; then
  echo "Error: kernel.bin too big for ${KERNEL_SECTORS} sectors ($KERNEL_SIZE > $KERNEL_BYTES)"
  exit 1
fi

echo "[*] Padding the kernel binary to fit ${KERNEL_SECTORS} sectors"
dd if=/dev/zero bs=1 count=$((KERNEL_BYTES - KERNEL_SIZE)) status=none >> "$BIN64/kernel.bin"
echo "[*] kernel.bin: ${KERNEL_SIZE} bytes -> padded to ${KERNEL_BYTES} bytes"

# -------------------------
# Build raw image: stage1 (1 sector) | stage2 (64 sectors) | kernel (64 sectors)
# -------------------------
echo "[*] Building the raw image of stage1, stage2, and kernel"
cat "$BIN16/stage1.bin" "$BIN32/stage2.bin" "$BIN64/kernel.bin" > "$IMG/os-img.bin"

IMG_SIZE=$(stat -c %s "$IMG/os-img.bin")
IMG_SECTORS=$(( (IMG_SIZE + 511) / 512 ))
echo "[*] os-img.bin: ${IMG_SIZE} bytes (${IMG_SECTORS} sectors)"
echo "[*] Running QEMU..."

qemu-system-x86_64 -drive format=raw,file="$IMG/os-img.bin"
