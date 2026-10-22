// platform.h - SoC memory map and peripheral register offsets.
#ifndef PLATFORM_H
#define PLATFORM_H

#include <stdint.h>

#define REG32(addr) (*(volatile uint32_t *)(uintptr_t)(addr))

#define RAM_BASE      0x80000000u
#define RAM_SIZE      0x00020000u

#define UART_BASE     0x10000000u
#define SPI_BASE      0x10001000u
#define TIMER_BASE    0x10002000u
#define GPIO_BASE     0x10003000u
#define INTC_BASE     0x10004000u
#define SIMCTRL_BASE  0x1000F000u

// ---------------- UART ----------------
#define UART_DATA        (UART_BASE + 0x00)
#define UART_STATUS      (UART_BASE + 0x04)
#define UART_CTRL        (UART_BASE + 0x08)
#define UART_BAUD_DIV    (UART_BASE + 0x0C)
#define UART_IRQ_EN      (UART_BASE + 0x10)
#define UART_IRQ_STATUS  (UART_BASE + 0x14)
#define UART_WATERMARK   (UART_BASE + 0x18)

#define UART_ST_TX_FULL     (1u << 0)
#define UART_ST_TX_EMPTY    (1u << 1)
#define UART_ST_TX_IDLE     (1u << 2)
#define UART_ST_RX_EMPTY    (1u << 3)
#define UART_ST_RX_FULL     (1u << 4)
#define UART_ST_RX_OVERRUN  (1u << 5)
#define UART_ST_FRAME_ERR   (1u << 6)
#define UART_ST_PARITY_ERR  (1u << 7)

#define UART_CTRL_TX_EN     (1u << 0)
#define UART_CTRL_RX_EN     (1u << 1)
#define UART_CTRL_PARITY_EN (1u << 2)
#define UART_CTRL_PARITY_ODD (1u << 3)
#define UART_CTRL_STOP2     (1u << 4)

#define UART_IRQ_TX_WM  (1u << 0)
#define UART_IRQ_RX_WM  (1u << 1)
#define UART_IRQ_ERR    (1u << 2)

#define UART_DATA_RX_EMPTY (1u << 31)

// ---------------- SPI ----------------
#define SPI_DATA        (SPI_BASE + 0x00)
#define SPI_STATUS      (SPI_BASE + 0x04)
#define SPI_CTRL        (SPI_BASE + 0x08)
#define SPI_CLK_DIV     (SPI_BASE + 0x0C)
#define SPI_CS          (SPI_BASE + 0x10)
#define SPI_IRQ_EN      (SPI_BASE + 0x14)
#define SPI_IRQ_STATUS  (SPI_BASE + 0x18)

#define SPI_ST_TX_FULL    (1u << 0)
#define SPI_ST_TX_EMPTY   (1u << 1)
#define SPI_ST_RX_EMPTY   (1u << 2)
#define SPI_ST_RX_FULL    (1u << 3)
#define SPI_ST_BUSY       (1u << 4)
#define SPI_ST_RX_OVERRUN (1u << 5)

#define SPI_CTRL_EN        (1u << 0)
#define SPI_CTRL_CPOL      (1u << 1)
#define SPI_CTRL_CPHA      (1u << 2)
#define SPI_CTRL_LSB_FIRST (1u << 3)

#define SPI_IRQ_TX_EMPTY    (1u << 0)
#define SPI_IRQ_RX_NOT_EMPTY (1u << 1)
#define SPI_IRQ_DONE        (1u << 2)
#define SPI_IRQ_OVERRUN     (1u << 3)

// ---------------- TIMER64 ----------------
#define TIMER_MTIME_LO     (TIMER_BASE + 0x00)
#define TIMER_MTIME_HI     (TIMER_BASE + 0x04)
#define TIMER_MTIMECMP_LO  (TIMER_BASE + 0x08)
#define TIMER_MTIMECMP_HI  (TIMER_BASE + 0x0C)
#define TIMER_CTRL         (TIMER_BASE + 0x10)
#define TIMER_MSIP         (TIMER_BASE + 0x14)

// ---------------- GPIO ----------------
#define GPIO_OUT         (GPIO_BASE + 0x00)
#define GPIO_IN          (GPIO_BASE + 0x04)
#define GPIO_DIR         (GPIO_BASE + 0x08)
#define GPIO_IRQ_EN      (GPIO_BASE + 0x0C)
#define GPIO_IRQ_STATUS  (GPIO_BASE + 0x10)
#define GPIO_IRQ_TYPE    (GPIO_BASE + 0x14)

// ---------------- INTC ----------------
#define INTC_PENDING  (INTC_BASE + 0x00)
#define INTC_ENABLE   (INTC_BASE + 0x04)
#define INTC_ACTIVE   (INTC_BASE + 0x08)

#define INTC_SRC_UART  (1u << 0)
#define INTC_SRC_SPI   (1u << 1)
#define INTC_SRC_GPIO  (1u << 2)

// ---------------- SIM_CTRL ----------------
#define SIM_PUTCHAR  (SIMCTRL_BASE + 0x00)
#define SIM_EXIT     (SIMCTRL_BASE + 0x04)

// ---------------- mcause values ----------------
#define MCAUSE_IRQ_BIT   0x80000000u
#define MCAUSE_MSI       (MCAUSE_IRQ_BIT | 3u)
#define MCAUSE_MTI       (MCAUSE_IRQ_BIT | 7u)
#define MCAUSE_MEI       (MCAUSE_IRQ_BIT | 11u)

#define CAUSE_MISALIGNED_FETCH  0
#define CAUSE_FETCH_ACCESS      1
#define CAUSE_ILLEGAL_INSN      2
#define CAUSE_BREAKPOINT        3
#define CAUSE_MISALIGNED_LOAD   4
#define CAUSE_LOAD_ACCESS       5
#define CAUSE_MISALIGNED_STORE  6
#define CAUSE_STORE_ACCESS      7
#define CAUSE_ECALL_M           11

#endif
