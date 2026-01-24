; The Boot Sequence is:
;   - Firmware runs and send POST which ensures all electrical devices are OK.
;   - Firmware runs BIOS which is code that sits directly on the motherboard and meant to be the entry point of PC.
;   - BIOS searches the first 512 bytes of every drive, and checks if they end with the magic number: 0x55AA
;   - BIOS copies these 512 bytes to address 0x7C00 and jumps to it
;   - This is where we are - stage 1.

[BITS 16]                 ; Setting 16-bit mode
[ORG 0x7C00]              ; Tells the compiler to start from 0x7C00

start:
	jmp 0x0000:main			; The calculation in memory we have is CS:Offset, which does (CS * 16) + Offset.
							; We already have ORG 0x7C00, which means we start at 0x7c00, and the Offset would grow incrementally
							; Therfore, we want to zero initliaze CS (by far jumping)

main:
				
	xor ax, ax				; When we pass DAP we save it in SI, and SI is at DS:SI
	mov ds, ax				; so we zero initliaze for the same reason we did in start 
	mov es, ax
	mov gs, ax
	
							; Initliaze stuff for the Stack:
	cli						; remove all interrupts as they push stuff into the stack and would cause undefined behaviour
	mov ss, ax				; sp would be regarded at SS:SP
	mov sp, 0x7C00
	mov bp, 0x7C00             
	
	jmp load_stage2

load_stage2:
    						; BIOS stores the current boot driveID in dl - No need to set it ourselves.
	mov si, DAP 			; DAP - Data Address Packet, defined later
    mov ah, 0x42
    int 0x13
    jc short error
	jmp 0x7E00 				; Jump into where the ram was written to

; Defining DAP for BIOS Interrupt 13h which reads from disk and writes to RAM
align 4                 ; Align on 4-byte boundary just to be safe
DAP:
    db 0x10             ; Packet Size: this tells the BIOS what version of DAP struct we're using
    db 0x00             ; Padding byte: Needs to be set to 0 if DAP runs in a loop
    dw 0x40             ; Count: Number of sectors to read (64 sectors - could be changed later on)

                        ; RAM address to write to is represented by (Segment * 16) + Offset
    dw 0x7E00           ; Offset - 0x700 which is directly after 0x7C00
    dw 0x0000           ; Segment

    dq 0x00000001       ; Disk sector to read from, each sector is 512 bytes.
                        ; the first one contains this file, the next sector will contain stage 2.

error:
	jmp $				; Do an infinite loop so cpu wont read garbage instructions and triple-fault

; Enlarge the file so it would be 512 bytes, 
; and the last 2 bytes are reserved for the magic number 0x55AA (little endian here)
times 510-($-$$) db 0
dw 0xAA55
