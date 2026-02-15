[BITS 64]
global kernel_entry
extern start_kernel

kernel_entry:
    ; Assuming stage2 already set RSP properly and aligned.
    call start_kernel

.hang:
    hlt
    jmp .hang
