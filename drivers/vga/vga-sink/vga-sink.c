#include "vga-sink.h"

static void vga_sink_init()
{
    vga_sync_cursor_from_hw();
}

static void vga_sink_putc(char c)
{
    vga_putc(c);
}

static void vga_sink_flush()
{
    vga_flush_cursor();
}

static void vga_sink_set_color(byte color)
{
    vga_set_color(color);
}

const ConsoleSink VGA_SINK =
{
    .init = vga_sink_init,
    .putc = vga_sink_putc,
    .flush = vga_sink_flush,
    .set_color = vga_sink_set_color
};