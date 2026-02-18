#include "vga.h"
#include "common/types.h"

static int row = 0;
static int col = 0;
static byte current_color = VGA_COLOR_DEFAULT;
volatile word* vga_buffer = (volatile word*) VGA_BUFFER_ADDRESS; // each cell is 2 bytes

static inline void outb(word port, byte val) {
    #if defined(__GNUC__) || defined(__clang__)
    __asm__ volatile ("outb %0, %1" : : "a"(val), "Nd"(port));
    #elif defined(_MSC_VER)
    __outbyte(port, val);
    #else
        #error "outb: unsupported compiler"
    #endif
}

static inline byte inb(word port) {
#if defined(__GNUC__) || defined(__clang__)
    byte ret;
    __asm__ volatile ("inb %1, %0" : "=a"(ret) : "Nd"(port));
    return ret;
#elif defined(_MSC_VER)
    return __inbyte(port);
#else
    #error "inb: unsupported compiler"
#endif
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

word vga_get_cursor_pos_from_hw()
{
    // 0x3D4 is the index port for vga controller (meaning the port in which we use to select a register)
    outb(0x3D4, 0x0F); //  0x0F is the lower byte of the cursor register
    byte low_byte = inb(0x3D5);

    outb(0x3D4, 0x0e); //  0x0E is the upper byte of the cursor register
    byte high_byte = inb(0x3D5);

    return (word)(high_byte << 8 | low_byte);
}

static void vga_hw_update_cursor()
{
    word pos = (word)(row * VGA_WIDTH + col);

    outb(0x3D4, 0x0F);
    outb(0x3D5, (byte)(pos & 0xFF));
    outb(0x3D4, 0x0E);
    outb(0x3D5, (byte)((pos >> 8) & 0xFF));
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
        vga_hw_update_cursor();
        return;
    }
    
    if (c == '\r') 
    {
        carriage_return();
        vga_hw_update_cursor();
        return;
    }

    if (col >= VGA_WIDTH) 
    {
        line_feed();
        carriage_return();
        vga_hw_update_cursor();
    }

    int index = GET_FLAT_INDEX(row, col);
    vga_buffer[index] = (current_color << 8) | c;
    col++;
    vga_hw_update_cursor();
}