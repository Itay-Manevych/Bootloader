#include "drivers/vga/vga.h"

void start_kernel()
{
    print_string("Kernel Loaded.");
    // Hang forever
    while(1);
}