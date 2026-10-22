// assert.h - freestanding shim: a failed assertion ends the run with code 99
#ifndef _ASSERT_H
#define _ASSERT_H
void exit(int code) __attribute__((noreturn));
#define assert(x) do { if (!(x)) exit(99); } while (0)
#endif
