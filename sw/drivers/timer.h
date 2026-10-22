// timer.h - TIMER64 driver (mtime/mtimecmp/msip).
#ifndef TIMER_H
#define TIMER_H

#include <stdint.h>

uint64_t timer_mtime(void);               // hi-lo-hi read
void     timer_set_mtime(uint64_t v);
void     timer_set_cmp(uint64_t v);       // glitch-free LO/HI update sequence
uint64_t timer_get_cmp(void);
void     timer_config(int enable, uint32_t prescale);
void     timer_msip(int set);
void     timer_irq_enable(void);          // mie.MTIE
void     timer_irq_disable(void);

#endif
