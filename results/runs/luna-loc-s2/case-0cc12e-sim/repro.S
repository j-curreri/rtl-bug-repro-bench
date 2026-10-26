#include "hyp.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  /* With TW set, WFI from VS-mode must raise a virtual-instruction trap. */
  li t0, (1 << 21)             /* mstatus.TW */
  csrs mstatus, t0
  ENTER_VS(vs_wfi)

vs_wfi:
  .word 0x10500073             /* WFI */
  /* TW requires a trap, so reaching this means the implementation is wrong. */
  FAIL(1)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 22                    /* virtual instruction */
  beq t0, t1, 1f
  FAIL(2)
1:
  PASS
