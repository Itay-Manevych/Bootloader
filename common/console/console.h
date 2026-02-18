#pragma once
#include "common/types.h"

typedef struct 
{
    void (*init)(void);
    void (*putc)(char c);
    void (*flush)(void);
    void (*set_color)(byte color);
} ConsoleSink; // sink is where output eventually will be written to

void console_set_sink(const ConsoleSink* sink);
void console_init();
void console_putc(char c);
void console_flush();
void console_set_color(byte color);