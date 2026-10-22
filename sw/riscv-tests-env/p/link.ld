/* Linker script for riscv-tests on this SoC: 128 KB RAM at 0x8000_0000. */
OUTPUT_ARCH( "riscv" )
ENTRY(_start)

MEMORY
{
  RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 128K
}

SECTIONS
{
  . = 0x80000000;
  .text.init : { *(.text.init) } > RAM
  . = ALIGN(0x1000);
  .tohost : { *(.tohost) } > RAM
  . = ALIGN(0x1000);
  .text : { *(.text) } > RAM
  . = ALIGN(0x1000);
  .data : { *(.data) } > RAM
  .bss : { *(.bss) } > RAM
  _end = .;
}
