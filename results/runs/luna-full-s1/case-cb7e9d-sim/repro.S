#include "test.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  /* Select trigger 0 and describe an 8-byte NAPOT execute range. */
  csrw tselect, zero
  la t0, napot_target
  ori t0, t0, 7
  csrw tdata2, t0

  /* type=6 (mcontrol6), match=1 (NAPOT), M-mode execute address. */
  li t0, 0x60000000000000c4
  csrw tdata1, t0

  /* Reaching this point means the address trigger did not fire. */
  j failed

  .balign 8
napot_target:
  j failed

failed:
  FAIL(1)

  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 3                   /* breakpoint exception */
  bne t0, t1, unexpected_trap
  PASS

unexpected_trap:
  FAIL(2)
