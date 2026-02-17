#include "drivers/vga/vga.h"
#include "common/third-party/mpaland/printf.h"

void start_kernel()
{
    set_current_cursor(16,0);
    printf("working?\n");
    // Hang forever
    while(1);
}