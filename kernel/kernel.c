#include "drivers/vga/vga.h"
#include "common/third-party/mpaland/printf.h"

void start_kernel()
{
    vga_sync_cursor_from_hw();
    printf("working?\n");
    // Hang forever
    while(1);
}