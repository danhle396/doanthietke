// stdio.h - freestanding shim: printf goes to the console (xprintf)
#ifndef _STDIO_H
#define _STDIO_H
#include <stddef.h>
int printf(const char *fmt, ...);
int sprintf(char *buf, const char *fmt, ...);
int putchar(int c);
#endif
