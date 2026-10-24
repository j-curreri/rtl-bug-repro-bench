/* Bare-metal layout for the CVA6 Verilator testharness: DRAM at 0x80000000. */
OUTPUT_ARCH("riscv")
ENTRY(_start)
SECTIONS
{
  . = 0x80000000;
  .text.init : { *(.text.init) }
  . = ALIGN(0x1000);
  .tohost : { *(.tohost) }
  . = ALIGN(0x1000);
  .text : { *(.text*) }
  . = ALIGN(0x1000);
  .data : { *(.data*) *(.rodata*) *(.sdata*) *(.bss*) *(.sbss*) }
  . = ALIGN(16);
  _stack_bottom = .;
  . += 0x4000;
  _stack_top = .;
  _end = .;
}
