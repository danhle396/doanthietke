// gpio.h - GPIO driver.
#ifndef GPIO_H
#define GPIO_H

#include <stdint.h>

void     gpio_set_dir(uint32_t out_mask);         // 1 = output
void     gpio_write(uint32_t value);
uint32_t gpio_read_out(void);
uint32_t gpio_read(void);                          // synchronized inputs
void     gpio_irq_config(uint32_t en_mask, uint32_t falling_mask);
uint32_t gpio_irq_status(void);
void     gpio_irq_clear(uint32_t mask);           // W1C

#endif
