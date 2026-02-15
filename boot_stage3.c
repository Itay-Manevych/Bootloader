#pragma once
#include "vga.h"

void boot_stage3()
{
    print_string("Welcome to C (Protected Mode)!");
    print_string("Next stop: Long Mode (64-bit)...");
    // Hang forever
    while(1);
}
