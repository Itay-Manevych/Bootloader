#include "vga.h"

#include <cstdint>

#define VGA_BUFFER 0xB8000
#define WHITE_ON_BLACK 0x05
#define PREVIOUS_STAGES_LINES_USED 12

size_t previous_lines_used = PREVIOUS_STAGES_LINES_USED;

void print_char(char c, int col, int row) {
    volatile char* video = (volatile char*)VGA_BUFFER;
    int index = (row * 80 + col) * 2; // 2 bytes per char (char + color)
    video[index] = c;
    video[index + 1] = WHITE_ON_BLACK;
}

void print_string(const char* str) {
    int col = 0;
    while (*str) {
        print_char(*str, col, previous_lines_used++);
        col++;
        str++;
    }
}