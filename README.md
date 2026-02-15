# Bootloader
Legacy BIOS bootloader

The purpose of this project exists so I can understand what really happens when a PC boots, from the first 512 bytes the BIOS loads, through switching CPU modes, all the way to jumping into my own kernel. 
The long-term goal is to grow this into a minimal OS.

## What it does (current)
- Stage 1 (boot sector, 512 bytes)
  - Loaded by BIOS at `0x7C00`
  - Uses BIOS Interrupt disk services (INT 13h) to load Stage 2
- Stage 2 (real mode (16 bit) -> protected mode (32 bit) -> long mode (64 bit))
  - Sets up a GDT
  - Enables A20 Fast Gate
  - Switches to 32-bit protected mode
  - Builds identity-mapped page tables (illustration can be found at identity_paging.md)
  - Enables paging + long mode
  - Jumps to the kernel entry point
- Kernel (64-bit)
  - Currently prints to VGA and halts

## Project layout
- `boot/` — stage1 + stage2 boot code
- `kernel/` — 64-bit kernel + entry stub
- `drivers/` — simple hardware drivers (VGA for now)
- `common/` — shared headers (e.g. `types.h`)
- `run_stages.sh` — builds a raw disk image and runs QEMU

## Build & run
Requirements:
- `nasm`
- `clang` (cross targets: `i386-elf`, `x86_64-elf`)
- `ld.lld`
- `llvm-objcopy`
- `qemu-system-x86_64`

Run:
```bash
./run_stages.sh