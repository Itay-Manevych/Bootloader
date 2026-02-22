[BITS 16]
global stage2_entry

%define NEWLINE 0x0D, 0x0A

; Indexes for the selectors once we move into protected mode - each selector is 8 bytes
%define GDT_DATA_SEGMENT_SELECTOR 0x08 
%define GDT_CODE32_SEGMENT_SELECTOR 0x10
%define GDT_CODE64_SEGMENT_SELECTOR 0x18

stage2_entry:
    jmp load_kernel

load_kernel:
    xor ax, ax
    mov ds, ax

    mov si, DAP
    mov ah, 0x42
    int 0x13            ; BIOS Interrupt in order to load the kernel into memory.
    jc error            ; CF==1 means that an error has occurred.
    jmp stage_2_start

; Defining DAP for BIOS Interrupt 13h which reads from disk and loades kernel to ram
; because after we jump to protected/long mode - there are no more Bios interrups!
align 4                 ; Align on 4-byte boundary just to be safe
DAP:
    db 0x10             ; Packet Size: this tells the BIOS what version of DAP struct we're using
    db 0x00             ; Padding byte: Needs to be set to 0 if DAP runs in a loop
    dw 0x40             ; Count: Number of sectors to read (64 sectors - could be changed later on)

                        ; RAM address to write to is represented by (Segment * 16) + Offset
                        ; We load the kernel to 0x10000 which is 64kib
                        ; therefore we need to make 0x10000 / 0x10 (16) in the segment
    dw 0x0000          
    dw 0x1000           ; Segment

    dq 0x00000041       ; Disk sector to read from, each sector is 512 bytes.
                        ; in boot_stage1.asm we loaded boot_stage1.asm into the first sector 
                        ; after that, we have 64 sectors (from sector 1 to sector 64)
                        ; therefore, we will read the kernel from sector 65!

error:
    jmp $               ; make qemu keep running

; real start after we actually loaded the kernel into memory!
; the kernel bytes in ram are now 0x00010000
stage_2_start:
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

    jmp GDT_CODE32_SEGMENT_SELECTOR:entry_protected_mode  ; The leap of faith - jumping into protected mode! 
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

ENTRY_CODE32_SEGMENT:
    dw 0xFFFF                   ; Lower part limit
    dw 0x0000                   ; Lower part base
    db 0x00                     ; Middle part base
    db 0b10011010               ; Access byte
    db 0b11000000 | 0b00001111  ; 0b00001111 = the upper part limit, 0b11000000 = flags
    db 0x00                     ; Upper part base

ENTRY_CODE64_SEGMENT:
    dw 0xFFFF                   ; Lower part limit
    dw 0x0000                   ; Lower part base
    db 0x00                     ; Middle part base
    db 0b10011010               ; Access byte
    db 0b10100000 | 0b00001111  ; 0b00001111 = the upper part limit, 0b10100000 = flags
    db 0x00                     ; Upper part base

GDT_END:

GDT_DESCRIPTION:
    dw GDT_END - GDT_START - 1  ; Limit: the maximum offset allowed within the GDT
    dd GDT_START                ; Base: the base address of the GDT

msg_stage2 db "[+] BOOTING", NEWLINE, "Loading Stage 1", NEWLINE, "Loading Stage 2....", NEWLINE, 0

[BITS 32]
; MSR - Model Specific Register, 0xC0000080 is its index
%define MSR_LONG_MODE 0xC0000080 

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

preapre_long_mode:
    extern setup_page_tables
    extern pml4_table_physical

    call setup_page_tables         ; Build the page tables in RAM
    
    mov eax, [pml4_table_physical]        ; Giving cr3 the physical address inside the RAM of PML4 Table
    mov cr3, eax                          ; The physical address of PML4 must stay less than 4GiB because stage2 loads it into CR3 using eax (which is only 32 bits)

    mov eax, cr4                ; Enabling PAE (Physical Address Extenstion) Paging, without it the paging structure would be wrong
    or  eax, (1 << 5)           ; PAE is the bit #5 (counting from 0)
    mov cr4, eax

    mov ecx, MSR_LONG_MODE     ; Preapre long mode
    rdmsr                      ; Read msr into EDX:EAX
    or  eax, (1 << 8)          ; Set the long mode bit on, which is the bit #8 (counting from 0)
    wrmsr                      ; Write back to msr

    mov eax, cr0               ; Enable Long Mode!
    or  eax, (1 << 31)         ; Set PG on
    mov cr0, eax

    jmp GDT_CODE64_SEGMENT_SELECTOR:entry_long_mode ; The leap of faith again :)

[BITS 64]
%define KERNEL_LOAD_ADDRESS 0x00010000

entry_long_mode:
    cld                                 ; Clear the direction flag

    cli                                 ; Ensure interrupts are disabled

    mov rsp, 0x90000
    and rsp, -16                        ; Clear the bottom 4 bits of RSP which rounds it down to a multiple of 16
    jmp KERNEL_LOAD_ADDRESS