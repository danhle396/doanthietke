// core_portme.h - CoreMark port for the RV32IMC SoC (bare metal, single
// context, static memory, timing with mcycle at 50 MHz, no floating point).
#ifndef CORE_PORTME_H
#define CORE_PORTME_H

#include <stdint.h>
#include <stddef.h>

#define HAS_FLOAT        0
#define HAS_TIME_H       0
#define USE_CLOCK        0
#define HAS_STDIO        0
#define HAS_PRINTF       0
#define MAIN_HAS_NOARGC  1
#define MAIN_HAS_NORETURN 0
#define SEED_METHOD      SEED_VOLATILE
#define MEM_METHOD       MEM_STATIC
#define MULTITHREAD      1
#define USE_PTHREAD      0
#define USE_FORK         0
#define USE_SOCKET       0
#define MEM_LOCATION     "STATIC"
#define COMPILER_VERSION "GCC" __VERSION__
#ifndef COMPILER_FLAGS
#define COMPILER_FLAGS   "-O2 (see scripts/build_sw.py)"
#endif

typedef int16_t   ee_s16;
typedef uint16_t  ee_u16;
typedef int32_t   ee_s32;
typedef uint8_t   ee_u8;
typedef uint32_t  ee_u32;
typedef uintptr_t ee_ptr_int;
typedef size_t    ee_size_t;
typedef ee_u32    CORE_TICKS;
typedef double    ee_f32;   // unused (HAS_FLOAT = 0)

#define NULL_ADDR ((void *)0)
#define align_mem(x) (void *)(4 + (((ee_ptr_int)(x)-1) & ~3))

typedef struct CORE_PORTABLE_S {
  ee_u8 portable_id;
} core_portable;

extern ee_u32 default_num_contexts;

void portable_init(core_portable *p, int *argc, char *argv[]);
void portable_fini(core_portable *p);
int  ee_printf(const char *fmt, ...);

#endif
