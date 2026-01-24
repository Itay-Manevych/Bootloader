[BITS 16]
[ORG 0x7E00]

start:
    xor ax, ax
    mov ds, ax
    mov si, msg

    print_string:
        mov al, [si]
        test al, al
        jz finish        
        mov ah, 0x0E
        int 0x10
        inc si 
        jmp print_string

    finish:
        jmp $

msg db "Hello from stage2!", 0