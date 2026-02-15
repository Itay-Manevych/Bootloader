[BITS 16]

%define NEWLINE 0x0D, 0x0A

; Indexes for the selectors once we move into protected mode - each selector is 8 bytes
%define GDT_DATA_SEGMENT_SELECTOR 0x08 
%define GDT_CODE_SEGMENT_SELECTOR 0x10

start:
    xor ax, ax
    mov ds, ax
    mov si, msg_stage2

print_string:
    mov al, [si]
    test al, al
    jz continue
    mov ah, 0x0E                ; BIOS interrupt to print a character
    int 0x10
    inc si
    jmp print_string

continue:
prepare_protected_mode:
    cli                         ; Disable interrupts

    in al, 0x92                 ; Enabling A20 Using Fast Gate
    or al, 0x02
    out 0x92, al

    lgdt [GDT_DESCRIPTION]      ; Setting GDT - Global Descriptor Table
                                ; in order to set the GDT, 
                                ; we need to load the GDT_DESCRIPTION label which is defined below,
                                ; into GDTR (GDT registry)

    mov eax, cr0                ; Setting CR0.PE lsb to 1 (switching to protected mode)
    or eax, 1
    mov cr0, eax

    jmp GDT_CODE_SEGMENT_SELECTOR:entry_protected_mode  ; The leap of faith - jumping into protected mode! 
                                                        ; in protected mode, the segements are basically indexes inside the GDT
                                                        ; so, we far jump which changes the code segement into the index we defined earlier


align 8                         ; Align for 8 bytes for safety                
GDT_START:
GDT_DATA:
    dq 0x00000000               ; The first entry must be null

ENTRY_DATA_SEGMENT:
    dw 0xFFFF                   ; Lower part limit
    dw 0x0000                   ; Lower part base
    db 0x00                     ; Middle part base
    db 0b10010010               ; Access byte
    db 0b11000000 | 0b00001111  ; 0b00001111 = the upper part limit, 0b11000000 = flags
    db 0x00                     ; Upper part base

ENTRY_CODE_SEGMENT:
    dw 0xFFFF                   ; Lower part limit
    dw 0x0000                   ; Lower part base
    db 0x00                     ; Middle part base
    db 0b10011010               ; Access byte
    db 0b11000000 | 0b00001111  ; 0b00001111 = the upper part limit, 0b11000000 = flags
    db 0x00                     ; Upper part base
GDT_END:

GDT_DESCRIPTION:
    dw GDT_END - GDT_START - 1  ; Limit: the maximum offset allowed within the GDT
    dd GDT_START                ; Base: the base address of the GDT

msg_stage2 db "[+] BOOTING", NEWLINE, "Loading Stage 1", NEWLINE, "Loading Stage 2....", NEWLINE, 0

[BITS 32]
entry_protected_mode:
    cld                                 ; Clear the direction flag

    cli                                 ; Ensure interrupts are disabled

    mov ax, GDT_DATA_SEGMENT_SELECTOR   ; Making all segments point to the gdt entry of the data segment (flat memory model)
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov gs, ax

    mov esp, 0x90000                    ; Setting the stack pointers
    mov ebp, esp

    ;extern boot_stage3		            ; Enter stage 3
    ;call boot_stage3
    

