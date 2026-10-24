#include "test.h"

/* M-mode interrupts must write mtval with zero. Trigger non-delegated
 * SSIP and STIP (both trap to M) and check mtval in the handler. */

  .text
  .globl test_main
test_main:
  csrw mideleg, zero
  csrw medeleg, zero
  csrw mie, zero
  li t0, (1 << 1) | (1 << 5)
  csrc mip, t0
  li s0, 0                      /* interrupts taken */
  li t0, (1 << 3)
  csrs mstatus, t0              /* mstatus.MIE */

  /* ---- test 1: supervisor software interrupt taken in M ---- */
  li s1, 0x8000000000000001
  li t0, -1
  csrw mtval, t0                /* garbage that must be overwritten */
  li t0, (1 << 1)
  csrs mie, t0
  csrs mip, t0                  /* raise SSIP -> interrupt */
  addi a1, a1, 1
  addi a1, a1, 1
  addi a1, a1, 1
  li t1, 1000
1: addi t1, t1, -1
  bnez t1, 1b
  li t0, 1
  bne s0, t0, fail_noint

  /* ---- test 2: supervisor timer interrupt taken in M ---- */
  li s1, 0x8000000000000005
  li t0, 0x5a5a5a5a
  csrw mtval, t0
  li t0, (1 << 5)
  csrs mie, t0
  csrs mip, t0                  /* raise STIP -> interrupt */
  addi a1, a1, 1
  addi a1, a1, 1
  addi a1, a1, 1
  li t1, 1000
1: addi t1, t1, -1
  bnez t1, 1b
  li t0, 2
  bne s0, t0, fail_noint

  PASS

fail_noint:
  FAIL(1)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t2, mcause
  bne t2, s1, fail_cause
  csrr t3, mtval
  bnez t3, fail_tval
  /* clear the pending bit and disable the source */
  li t4, (1 << 1) | (1 << 5)
  csrc mip, t4
  csrc mie, t4
  addi s0, s0, 1
  mret

fail_cause:
  FAIL(2)
fail_tval:
  FAIL(3)
