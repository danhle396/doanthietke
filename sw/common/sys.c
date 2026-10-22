// sys.c - exit(), tohost/fromhost, default trap dispatch.
#include <stdint.h>
#include "platform.h"
#include "csr.h"
#include "sys.h"
#include "xprintf.h"
#ifdef CONSOLE_UART
#include "uart.h"
#endif

// HTIF mailboxes (Spike needs both symbols); written by exit().
volatile uint64_t tohost __attribute__((section(".tohost"), aligned(64)));
volatile uint64_t fromhost __attribute__((section(".tohost"), aligned(64)));

void __attribute__((noreturn)) exit(int code) {
#ifdef CONSOLE_UART
  uart_flush();
#endif
  REG32(SIM_EXIT) = (uint32_t)code;                       // RTL simulation
  *(volatile uint32_t *)&tohost = ((uint32_t)code << 1) | 1u;  // Spike / tohost
  for (;;) ;
}

// Console set-up before main(): CONSOLE=uart uses BAUD_DIV = CONSOLE_BAUD_DIV
// (0 = 16 clocks/bit for fast simulation; the demo uses 26 = 115200 @ 50 MHz).
#ifndef CONSOLE_BAUD_DIV
#define CONSOLE_BAUD_DIV 0
#endif
void console_init(void) {
#ifdef CONSOLE_UART
  uart_init(CONSOLE_BAUD_DIV, UART_CTRL_TX_EN | UART_CTRL_RX_EN);
#endif
}

// ---------------- Default (weak) handlers ----------------
void __attribute__((weak)) irq_timer_handler(void) {
  // No handler installed: disable the source to avoid an interrupt storm.
  csr_clear(mie, MIE_MTIE);
}

void __attribute__((weak)) irq_software_handler(void) {
  REG32(TIMER_MSIP) = 0;
}

void __attribute__((weak)) irq_external_handler(void) {
  csr_clear(mie, MIE_MEIE);
}

void __attribute__((weak)) exception_handler(uint32_t mcause, uint32_t mepc, uint32_t mtval) {
  xprintf("\nUNEXPECTED TRAP mcause=%x mepc=%x mtval=%x\n", mcause, mepc, mtval);
  exit(0x100 + (int)mcause);
}

void __attribute__((weak)) trap_handler(uint32_t mcause, uint32_t mepc, uint32_t mtval) {
  if (mcause & MCAUSE_IRQ_BIT) {
    switch (mcause) {
      case MCAUSE_MTI: irq_timer_handler(); break;
      case MCAUSE_MSI: irq_software_handler(); break;
      case MCAUSE_MEI: irq_external_handler(); break;
      default: exception_handler(mcause, mepc, mtval); break;
    }
  } else {
    exception_handler(mcause, mepc, mtval);
  }
}

void set_mtvec_direct(void) {
  extern void trap_entry(void);
  csr_write(mtvec, (uint32_t)(uintptr_t)&trap_entry);
}

void set_mtvec_vectored(void) {
  extern void trap_vector_table(void);
  csr_write(mtvec, (uint32_t)(uintptr_t)&trap_vector_table | 1u);
}
