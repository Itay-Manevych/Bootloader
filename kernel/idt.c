#include "idt.h"
#include "common/types.h"

#define IDT_TABLE_SIZE 256
#define GDT_CODE64_SEGMENT_SELECTOR 0x18

typedef struct __attribute__((packed)) // must be packed so there wont be no padding! exactly 16 bytes 
{
   word address_low;        // offset bits 0..15
   word selector;          // a code segment selector in GDT or LDT
   byte  ist;             // bits 0..2 holds Interrupt Stack Table offset, rest of bits zero.
   byte  type_attributes; // gate type, dpl, and p fields
   word address_mid;        // offset bits 16..31
   dword address_high;        // offset bits 32..63
   dword zero;            // reserved
}  InterruptDescriptor;

typedef struct __attribute__((packed)) 
{
    word size;
    qword base_address;
} IdtPtr;

InterruptDescriptor idt_table[IDT_TABLE_SIZE];
IdtPtr idt_ptr;

void* memset_(void* address, int value, size_t length) // also in page tables setup, will move it later
{
    byte* p = (byte*)address;
    byte val = (byte)value;
    for (size_t i = 0; i < length; i++) 
    {
        p[i] = val;
    }
    return address;
}

void set_gate(size_t vector, void* handler_address, byte flags)
{
    idt_table[vector] = (InterruptDescriptor){
        .address_low = (uintptr_t) handler_address & 0xFFFF,
        .address_mid =  ((uintptr_t) handler_address >> 16) & 0xFFFF,
        .address_high = ((uintptr_t) handler_address >> 32) & 0xFFFFFFFF,
        .ist = (byte) 0,
        .type_attributes = flags,
        .selector = (word) GDT_CODE64_SEGMENT_SELECTOR
    };
}

init_table()
{
    idt_ptr = (IdtPtr){
        .size = sizeof(idt_table) - 1,
        .base_address = &idt_table[0]
    };
    
    memset_(idt_table, 0, sizeof(idt_table));



    
}
