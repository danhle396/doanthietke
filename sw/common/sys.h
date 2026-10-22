// sys.h - runtime entry points shared by all programs.
#ifndef SYS_H
#define SYS_H

#include <stdint.h>

void __attribute__((noreturn)) exit(int code);

// Trap dispatch (all weak, override in the program).
void trap_handler(uint32_t mcause, uint32_t mepc, uint32_t mtval);
void exception_handler(uint32_t mcause, uint32_t mepc, uint32_t mtval);
void irq_timer_handler(void);
void irq_software_handler(void);
void irq_external_handler(void);

void set_mtvec_direct(void);
void set_mtvec_vectored(void);

#endif
