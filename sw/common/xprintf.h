// xprintf.h - minimal printf: %d %u %x %X %s %c %%, field width, '0' pad, '-' left.
#ifndef XPRINTF_H
#define XPRINTF_H

#include <stdarg.h>

void xputc(char c);   // console output (CONSOLE=uart or CONSOLE=sim)
void xputs(const char *s);
int  xprintf(const char *fmt, ...);
int  xvprintf(const char *fmt, va_list ap);
int  xsprintf(char *buf, const char *fmt, ...);
int  xvsprintf(char *buf, const char *fmt, va_list ap);

#endif
