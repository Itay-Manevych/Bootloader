#pragma once
#include "common/log.h"

__attribute__((noreturn))
static inline void PANIC(const char* msg)
{
    LOGE("PANIC: %s\n", msg);
    for (;;) { __asm__ volatile ("cli; hlt"); }
}

#define PANICF(fmt, ...) do { \
    LOGE("PANIC: " fmt "\n", ##__VA_ARGS__); \
    for (;;) { __asm__ volatile ("cli; hlt"); } \
} while (0)
