#pragma once
#include "common/log.h"

__attribute__((noreturn))
static inline void PANIC(const char* msg)
{
    LOGE("PANIC: %s\n", msg);
    for (;;) { __asm__ volatile ("cli; hlt"); }
}
