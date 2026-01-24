[BITS 16]
[ORG 0x7E00]

%define CRLF 0x0D, 0x0A

start:
    xor ax, ax
    mov ds, ax
    mov si, print_message

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

print_message db "[+] BOOTING", CRLF, "Loading Stage 1", CRLF, "Loading Stage 2....", CRLF, 0