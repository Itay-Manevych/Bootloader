#pragma once
#include "common/third-party/mpaland/printf.h"
#include "common/console/console.h"
#include "common/console/console_colors.h"

#define LOG_COLORED(color, prefix, fmt, ...) do { \
    console_set_color(color); \
    printf(prefix fmt, ##__VA_ARGS__); \
    console_set_color(CONSOLE_COLOR_DEFAULT); \
    console_flush(); \
} while (0)

#define LOGI(fmt, ...)  LOG_COLORED(CONSOLE_COLOR_DEFAULT, "[I] ", fmt, ##__VA_ARGS__)
#define LOGOK(fmt, ...) LOG_COLORED(CONSOLE_COLOR_OK,      "[+] ", fmt, ##__VA_ARGS__)
#define LOGW(fmt, ...)  LOG_COLORED(CONSOLE_COLOR_WARN,    "[W] ", fmt, ##__VA_ARGS__)
#define LOGE(fmt, ...)  LOG_COLORED(CONSOLE_COLOR_ERR,     "[E] ", fmt, ##__VA_ARGS__)
