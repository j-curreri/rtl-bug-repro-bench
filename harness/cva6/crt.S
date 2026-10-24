#include "test.h"

  .section .text.init
  .globl _start
_start:
  la sp, _stack_top
  la t0, trap_handler
  csrw mtvec, t0
  j test_main

/* Default handler: any unexpected trap fails with code 127 (mcause in t6 for debugging). */
  .weak trap_handler
  .align 2
trap_handler:
  csrr t6, mcause
  FAIL(127)

  .globl _halt
_halt:
  la t0, tohost
  sd a0, 0(t0)
1: j 1b

  .section .tohost, "aw", @progbits
  .align 6
  .globl tohost
tohost: .dword 0
  .align 6
  .globl fromhost
fromhost: .dword 0
