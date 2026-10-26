#include "hyp.h"

/* Illegal instruction executed in VS-mode, trapping to M-mode (medeleg = 0).
 * A non-guest-page-fault trap must leave mtval2 zero. */

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  csrw medeleg, zero
  csrw mideleg, zero

  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  HGATP_ON
  csrw vsatp, zero

  ENTER_VS(guest)

guest:
  .word 0
  PASS

  .globl trap_handler
  .align 2
trap_handler:
  csrr t1, mcause
  li t2, 2                       /* illegal instruction */
  bne t1, t2, 1f
  csrr t1, mtval2
  bnez t1, 3f
  csrr t1, mstatus
  srli t2, t1, 39
  andi t2, t2, 1                 /* MPV */
  beqz t2, 4f
  PASS
1: FAIL(1)
3: FAIL(3)
4: FAIL(4)

HYP_TABLES
