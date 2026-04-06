#include "common/mem/mem.h"
#include "common/types.h"

void* memset_(void* address, int value, size_t length)
{
    byte* p = (byte*)address;
    byte val = (byte)value;
    for (size_t i = 0; i < length; i++) {
        p[i] = val;
    }
    return address;
}
