#include "common/third-party/mpaland/printf.h"
#include "drivers/vga/vga.h"

void _putchar(char character)
{
    vga_putc(character);
}