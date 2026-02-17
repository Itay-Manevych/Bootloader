#pragma once
#include <stdint.h>
#include "common/types.h"

#define VGA_BUFFER_ADDRESS 0xB8000
#define VGA_WIDTH 80
#define VGA_HEIGHT 25
#define GET_FLAT_INDEX(row, col) ((row) * VGA_WIDTH + col)
enum { 
    VGA_COLOR_DEFAULT = 0x07, // light gray
    VGA_COLOR_SUCCESS = 0x0A, // light green
    VGA_COLOR_ERROR = 0x0C    // light red
};

void set_current_cursor(int r, int c);
void set_current_color(byte color);
void vga_putc(char c);
