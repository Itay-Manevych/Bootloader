#include "idt.h"
#include "common/types.h"
#include "common/panic.h"
#include <stddef.h>

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

static const char* const exception_names[32] = {
    "#DE",  // 0  Divide Error
    "#DB",  // 1  Debug
    "NMI",  // 2
    "#BP",  // 3  Breakpoint
    "#OF",  // 4  Overflow
    "#BR",  // 5  Bound Range Exceeded
    "#UD",  // 6  Invalid Opcode
    "#NM",  // 7  Device Not Available
    "#DF",  // 8  Double Fault
    "CSO",  // 9  Coprocessor Segment Overrun (legacy)
    "#TS",  // 10 Invalid TSS
    "#NP",  // 11 Segment Not Present
    "#SS",  // 12 Stack-Segment Fault
    "#GP",  // 13 General Protection
    "#PF",  // 14 Page Fault
    "RES",  // 15 Reserved
    "#MF",  // 16 x87 FP Exception
    "#AC",  // 17 Alignment Check
    "#MC",  // 18 Machine Check
    "#XM",  // 19 SIMD FP Exception
    "#VE",  // 20 Virtualization Exception
    "#CP",  // 21 Control Protection Exception
    "RES", "RES", "RES", "RES", "RES", "RES", "RES", "RES", "RES", "RES", // 22-31
};

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

void idt_set_descriptor(size_t vector, void* handler_address, byte flags)
{
    idt_table[vector] = (InterruptDescriptor){
        .address_low = (uintptr_t) handler_address & 0xFFFF,
        .address_mid =  ((uintptr_t) handler_address >> 16) & 0xFFFF,
        .address_high = ((uintptr_t) handler_address >> 32) & 0xFFFFFFFF,
        .selector = (word) GDT_CODE64_SEGMENT_SELECTOR,
        .type_attributes = flags,
        .ist = (byte) 0,
        .zero = (dword) 0
    };
}
__attribute__((noreturn))
void exception_handler(qword vector, qword error_code);
void exception_handler(qword vector, qword error_code) {
    const char* name = (vector < 32) ? exception_names[vector] : "INT"; // if its >= 32 then its an interrupt, not an exception
    PANICF("EXCEPTION %s (vec=%u) err=0x%x", name, vector, error_code);
}

extern void* isr_stub_table[];

void idt_init()
{
    idt_ptr = (IdtPtr){
        .size = sizeof(idt_table) - 1,
        .base_address = (qword)(uintptr_t)&idt_table[0]
    };
    memset_(idt_table, 0, sizeof(idt_table));

    for (size_t vector = 0; vector < 32; vector++) {
        idt_set_descriptor(vector, isr_stub_table[vector], 0x8E);
    }
    __asm__ volatile ("lidt %0" : : "m"(idt_ptr)); // load the new IDT
}
