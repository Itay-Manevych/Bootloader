#pragma once
#include "common/types.h"

#define VGA_BUFFER_ADDRESS 0xB8000
#define VGA_WIDTH 80
#define VGA_HEIGHT 25
#define VGA_SCREEN_SIZE VGA_WIDTH * VGA_HEIGHT
#define GET_FLAT_INDEX(row, col) ((row) * VGA_WIDTH + col)
enum { 
    VGA_COLOR_DEFAULT = 0x07, // light gray
    VGA_COLOR_SUCCESS = 0x0A, // light green
    VGA_COLOR_ERROR = 0x0C    // light red
};

void vga_sync_cursor_from_hw();
void vga_flush_cursor();
void set_current_color(byte color);
void vga_putc(char c);
void vga_print_string(const char* vga_print_string);
