
#pragma once
#include "../../common/types.h"

static inline void outb(word port, byte val) 
{
    __asm__ volatile ("outb %0, %1" : : "a"(val), "Nd"(port));
}

static inline byte inb(word port) 
{
    byte ret;
    __asm__ volatile ("inb %1, %0" : "=a"(ret) : "Nd"(port));
    return ret;
}