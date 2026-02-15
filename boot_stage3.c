#pragma once
#include "vga.h"

void boot_stage3()
{
    print_string("Welcome to C (Long Mode)!!!!");
    // Hang forever
    while(1);
}
