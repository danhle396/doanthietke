// csr.h - CSR access helpers (inline asm).
#ifndef CSR_H
#define CSR_H

#include <stdint.h>

#define csr_read(csr) ({ uint32_t __v; \
    __asm__ volatile ("csrr %0, " #csr : "=r"(__v) :: "memory"); __v; })
#define csr_write(csr, val) ({ uint32_t __v = (uint32_t)(val); \
    __asm__ volatile ("csrw " #csr ", %0" :: "rK"(__v) : "memory"); })
#define csr_set(csr, val) ({ uint32_t __v = (uint32_t)(val); \
    __asm__ volatile ("csrs " #csr ", %0" :: "rK"(__v) : "memory"); })
#define csr_clear(csr, val) ({ uint32_t __v = (uint32_t)(val); \
    __asm__ volatile ("csrc " #csr ", %0" :: "rK"(__v) : "memory"); })

#define MSTATUS_MIE  (1u << 3)
#define MSTATUS_MPIE (1u << 7)
#define MIE_MSIE     (1u << 3)
#define MIE_MTIE     (1u << 7)
#define MIE_MEIE     (1u << 11)

static inline void irq_global_enable(void)  { csr_set(mstatus, MSTATUS_MIE); }
static inline void irq_global_disable(void) { csr_clear(mstatus, MSTATUS_MIE); }

#endif
