// string.h - freestanding shim (implemented in sw/common/libc_min.c)
#ifndef _STRING_H
#define _STRING_H
#include <stddef.h>
void  *memcpy(void *dst, const void *src, size_t n);
void  *memset(void *dst, int c, size_t n);
void  *memmove(void *dst, const void *src, size_t n);
int    memcmp(const void *a, const void *b, size_t n);
char  *strcpy(char *dst, const char *src);
int    strcmp(const char *a, const char *b);
size_t strlen(const char *s);
#endif
