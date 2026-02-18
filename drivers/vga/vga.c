#include "vga.h"
#include "common/types.h"
#include "common/port-io/port-io.h"

static int row = 0;
static int col = 0;
static byte current_color = VGA_COLOR_DEFAULT;
volatile word* vga_buffer = (volatile word*) VGA_BUFFER_ADDRESS; // each cell is 2 bytes

static word vga_get_cursor_pos_from_hw()
{
    // 0x3D4 is the index port for vga controller (meaning the port in which we use to select a register)
    outb(0x3D4, 0x0F); //  choose to talk to the cursor register, which is 0x0F and pass him the lower byte
    byte lower_byte = inb(0x3D5);
    
    outb(0x3D4, 0x0e); //  0x0E is the upper byte of the cursor register
    byte upper_byte = inb(0x3D5);
    
    return (word)(upper_byte << 8 | lower_byte);
}

static void vga_update_cursor_hw()
{
    word pos = (word)(row * VGA_WIDTH + col);
    
    // 0x3D4 is the index port for vga controller (meaning the port in which we use to select a register)
    outb(0x3D4, 0x0F); // choose to talk to the cursor register, which is 0x0F and pass him the lower byte
    outb(0x3D5, (byte)(pos & 0xFF));
    
    outb(0x3D4, 0x0E); // choose to talk to the upper byte of the cursor register
    outb(0x3D5, (byte)((pos >> 8) & 0xFF));
}

void set_current_cursor(int r, int c) 
{
    if (r < 0 || r >= VGA_HEIGHT || c < 0 || c >= VGA_WIDTH) 
    {
        return;
    }
    row = r;
    col = c;
}

void set_current_color(byte color) 
{
    current_color = color;
}

void vga_sync_cursor_from_hw()
{
    word pos = vga_get_cursor_pos_from_hw();
    if (pos >= VGA_SCREEN_SIZE) 
    {
        pos = 0;
    }
    
    set_current_cursor(pos / VGA_WIDTH, pos % VGA_WIDTH);
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

void vga_flush_cursor()
{
    vga_update_cursor_hw();
}

void vga_print_string(const char* str) 
{
    while (str[0] != '\0') 
    {
        vga_putc(str[0]);
        str++;    
    }
    vga_flush_cursor();
}