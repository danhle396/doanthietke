// gpio.c - GPIO driver.
#include "gpio.h"
#include "platform.h"

void gpio_set_dir(uint32_t out_mask) { REG32(GPIO_DIR) = out_mask; }
void gpio_write(uint32_t value)      { REG32(GPIO_OUT) = value; }
uint32_t gpio_read_out(void)         { return REG32(GPIO_OUT); }
uint32_t gpio_read(void)             { return REG32(GPIO_IN); }

void gpio_irq_config(uint32_t en_mask, uint32_t falling_mask) {
  REG32(GPIO_IRQ_TYPE) = falling_mask;
  REG32(GPIO_IRQ_STATUS) = 0xFFFFu;   // drop stale flags
  REG32(GPIO_IRQ_EN) = en_mask;
}

uint32_t gpio_irq_status(void)    { return REG32(GPIO_IRQ_STATUS); }
void gpio_irq_clear(uint32_t mask) { REG32(GPIO_IRQ_STATUS) = mask; }
