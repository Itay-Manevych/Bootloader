#include "drivers/vga/vga.h"

void start_kernel()
{
    print_string("Kernel Loaded.", 16);
    // Hang forever
    while(1);
}