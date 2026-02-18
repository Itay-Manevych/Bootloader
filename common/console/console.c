#include "console.h"
#include "drivers/vga/vga-sink/vga-sink.h"

static const ConsoleSink* current_sink = 0;

void console_set_sink(const ConsoleSink* sink)
{
    current_sink = sink;
}

void console_init()
{
    if (current_sink && current_sink->init) 
    {
        current_sink->init();
    }
}

void console_putc(char c)
{
    if (current_sink && current_sink->putc) 
    {
        current_sink->putc(c);
        if (c == '\n') 
        {
            console_flush();
        }
    }
}

void console_flush()
{
    if (current_sink && current_sink->flush) 
    {
        current_sink->flush();
    } 
}

void console_set_color(byte color)
{
    if (current_sink && current_sink->set_color) 
    {
        current_sink->set_color(color);
    } 
}