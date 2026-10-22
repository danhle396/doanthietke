// xprintf.c - minimal printf for bare-metal firmware (no floating point).
#include <stdint.h>
#include "xprintf.h"
#include "platform.h"

#ifdef CONSOLE_UART
#include "uart.h"
void xputc(char c) { uart_putc(c); }
#else
void xputc(char c) { REG32(SIM_PUTCHAR) = (uint8_t)c; }
#endif

void xputs(const char *s) {
  while (*s) xputc(*s++);
}

typedef struct {
  char *buf;   // NULL -> console
  int   n;
} out_t;

static void out_ch(out_t *o, char c) {
  if (o->buf) o->buf[o->n] = c;
  else        xputc(c);
  o->n++;
}

static void out_num(out_t *o, uint32_t v, unsigned base, int neg, int width, int zero,
                    int left, int upper) {
  char tmp[12];
  int len = 0;
  const char *digits = upper ? "0123456789ABCDEF" : "0123456789abcdef";
  do {
    tmp[len++] = digits[v % base];
    v /= base;
  } while (v);
  int total = len + (neg ? 1 : 0);
  if (!left && !zero)
    for (; total < width; total++) out_ch(o, ' ');
  if (neg) out_ch(o, '-');
  if (!left && zero)
    for (; total < width; total++) out_ch(o, '0');
  while (len) out_ch(o, tmp[--len]);
  if (left)
    for (; total < width; total++) out_ch(o, ' ');
}

static int do_printf(out_t *o, const char *fmt, va_list ap) {
  for (; *fmt; fmt++) {
    if (*fmt != '%') {
      out_ch(o, *fmt);
      continue;
    }
    fmt++;
    int left = 0, zero = 0, width = 0;
    if (*fmt == '-') { left = 1; fmt++; }
    if (*fmt == '0') { zero = 1; fmt++; }
    while (*fmt >= '0' && *fmt <= '9') width = width * 10 + (*fmt++ - '0');
    if (*fmt == 'l') fmt++;  // accept %lu / %lx (32-bit long)
    switch (*fmt) {
      case 'd': {
        int32_t v = va_arg(ap, int32_t);
        out_num(o, v < 0 ? (uint32_t)(-v) : (uint32_t)v, 10, v < 0, width, zero, left, 0);
        break;
      }
      case 'u': out_num(o, va_arg(ap, uint32_t), 10, 0, width, zero, left, 0); break;
      case 'x': out_num(o, va_arg(ap, uint32_t), 16, 0, width, zero, left, 0); break;
      case 'X': out_num(o, va_arg(ap, uint32_t), 16, 0, width, zero, left, 1); break;
      case 'c': out_ch(o, (char)va_arg(ap, int)); break;
      case 's': {
        const char *s = va_arg(ap, const char *);
        int len = 0;
        while (s[len]) len++;
        if (!left) for (int i = len; i < width; i++) out_ch(o, ' ');
        while (*s) out_ch(o, *s++);
        if (left) for (int i = len; i < width; i++) out_ch(o, ' ');
        break;
      }
      case '%': out_ch(o, '%'); break;
      case '\0': return o->n;
      default: out_ch(o, '%'); out_ch(o, *fmt); break;
    }
  }
  return o->n;
}

int xvprintf(const char *fmt, va_list ap) {
  out_t o = {0, 0};
  return do_printf(&o, fmt, ap);
}

int xprintf(const char *fmt, ...) {
  va_list ap;
  va_start(ap, fmt);
  int n = xvprintf(fmt, ap);
  va_end(ap);
  return n;
}

int xsprintf(char *buf, const char *fmt, ...) {
  va_list ap;
  out_t o = {buf, 0};
  va_start(ap, fmt);
  do_printf(&o, fmt, ap);
  va_end(ap);
  buf[o.n] = '\0';
  return o.n;
}
