#include "vga.h"
#include "common/types.h"

static int row = 0;
static int col = 0;
static byte current_color = VGA_COLOR_DEFAULT;
volatile word* vga_buffer = (volatile word*) VGA_BUFFER_ADDRESS; // each cell is 2 bytes

void set_current_cursor(int r, int c) 
{
    row = r;
    col = c;
}

void set_current_color(byte color) 
{
    current_color = color;
}

static void line_feed() 
{
    row++;
    if (row >= VGA_HEIGHT) {
        row = VGA_HEIGHT - 1; // TODO: Create scrolling, this is just temporary.
    }
}

static void carriage_return() 
{
    col = 0;
}

void vga_putc(char c) 
{
    if (c == '\n') 
    {
        line_feed();
        carriage_return();
        return;
    }

    if (c == '\r') 
    {
        carriage_return();
        return;
    }

    if (col >= VGA_WIDTH) 
    {
        line_feed();
        carriage_return();
    }

    int index = GET_FLAT_INDEX(row, col);
    vga_buffer[index] = (current_color << 8) | c;
    col++;
}