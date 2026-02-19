#include "drivers/vga/vga-sink/vga-sink.h"
#include "common/third-party/mpaland/printf.h"
#include "common/console/console.h"
#include "common/log.h"
#include "idt.h"

void start_kernel()
{
    console_set_sink(&VGA_SINK);
    console_init();
    LOGOK("Made it to Long mode :)\n");
    idt_init();
    __asm__ volatile ("ud2");
    // Hang forever
    while(1);
}