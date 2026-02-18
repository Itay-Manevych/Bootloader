// We map virtual memory to phyiscal memory. 
// as of write now, 1GiB is enough memory to map for the boot process
// each page size is 4KiB, so we need 1GiB / 4KiB = 262144 pages to map the entire memory.
// Since we are going to be in 64bit mode, each entry will be 8 bytes, so each page table will be 4KiB / 8 = 512 entries.
// the table hierarchy are PML4T->PDPT->PDT->PT->Physical Memory

#include <stdint.h>
#include <stddef.h>
#include "common/third-party/mpaland/printf.h"
#include "drivers/vga/vga.h"
#include "common/types.h"

#define MEMORY_SIZE 0x40000000 // 1GiB
#define PAGE_SIZE 0x1000 // 4KiB
#define ENTRIES PAGE_SIZE / 8
#define PAGE_COVERAGE ((qword)ENTRIES * (qword)PAGE_SIZE)
#define BASE_PAGE_TABLES_ADDRESS 0x02000000 // Page tables start at 32 MiB, Kernel loads at 64 KiB
#define FLAGS 0b11 // PRESENT | RW (Read-Write)

typedef struct 
{
    qword data[PAGE_SIZE / sizeof(qword)];
} PageTable;

qword next_free_address = BASE_PAGE_TABLES_ADDRESS;

void fill_identity_pt(PageTable* pt, qword base);

void* memset_(void* address, int value, size_t length) 
{
    byte* p = (byte*)address;
    byte val = (byte)value;
    for (size_t i = 0; i < length; i++) 
    {
        p[i] = val;
    }
    return address;
}

void* alloc_table() 
{
    PageTable* t = (PageTable*)(uintptr_t)next_free_address;
    memset_(t->data, 0, sizeof(t->data));
    next_free_address += 0x1000;
    return t;
}

void initliaze_pdt_table(PageTable* pdt) 
{
    for (size_t i = 0; i < ENTRIES; i++) 
    {
        PageTable* pt = (PageTable*)alloc_table();
        pdt->data[i] = (qword)(uintptr_t)pt | FLAGS;

        // Each page coveres 2Mib because we have 512 entries and each entry holds 4kib.
        qword base = PAGE_COVERAGE * i;
        fill_identity_pt(pt, base);
    }
    printf("Succesfully mapped the virtual addresses to physical addresses!\n");
}

void fill_identity_pt(PageTable* pt, qword base) 
{
    for (size_t i = 0; i < ENTRIES; i++) 
    {
        // pt->data[i] is an address to a physical frame, that takes 4KiB (as page size and a frame are the same size)
       qword physical_address = base + (qword)i * PAGE_SIZE;
       pt->data[i] = physical_address | FLAGS;
    }
}

dword pml4_table_physical = 0;

void setup_page_tables() 
{
    vga_sync_cursor_from_hw();
    set_current_color(VGA_COLOR_SUCCESS);
    printf("Welcome to Protected Mode!\n");
    printf("Next stop: Long Mode (64-bit)...\n");
    printf("Right now setting page tables...\n");
    PageTable* pml4 = (PageTable*)alloc_table();
    PageTable* pdpt = (PageTable*)alloc_table();
    PageTable* pdt = (PageTable*)alloc_table();

    pml4->data[0] = (qword)(uintptr_t)pdpt | FLAGS;
    pdpt->data[0] = (qword)(uintptr_t)pdt | FLAGS;

    initliaze_pdt_table(pdt);

    pml4_table_physical = (dword)(uintptr_t)pml4;
    set_current_color(VGA_COLOR_DEFAULT);
}
