/* link.ld - firmware linker script: 128 KB RAM at 0x8000_0000,
   .text starts with _start (crt0), .tohost holds tohost/fromhost,
   8 KB stack at the top of RAM. */
OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
  RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 128K
}

STACK_SIZE = 8K;

SECTIONS
{
  .text : {
    *(.text.init)
    *(.text.trap)
    *(.text .text.*)
  } > RAM

  .rodata : {
    . = ALIGN(4);
    *(.rodata .rodata.* .srodata .srodata.*)
  } > RAM

  .tohost : ALIGN(64) {
    *(.tohost)
  } > RAM

  .data : {
    . = ALIGN(4);
    *(.data .data.*)
    __global_pointer$ = . + 0x800;
    *(.sdata .sdata.*)
  } > RAM

  .bss (NOLOAD) : {
    . = ALIGN(4);
    _bss_start = .;
    *(.sbss .sbss.* .bss .bss.* COMMON)
    . = ALIGN(4);
    _bss_end = .;
  } > RAM

  _end = .;
  _stack_top = ORIGIN(RAM) + LENGTH(RAM);
  _stack_bottom = _stack_top - STACK_SIZE;
  ASSERT(_end <= _stack_bottom, "program overlaps the stack")
}
