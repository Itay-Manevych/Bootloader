section .data
section .bss

section .text 
	global _start

_start:
; Initalize the entire 512 bytes, but keep the last 2 bytes for the magic number 0x55AA (little endian here)
times 510-($-$$) db 0
dw 0xAA55
