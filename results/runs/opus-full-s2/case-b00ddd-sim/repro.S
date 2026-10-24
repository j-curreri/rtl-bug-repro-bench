#include "hyp.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  csrw medeleg, zero
  csrw hedeleg, zero
  csrw hgatp, zero
  csrw vsatp, zero
  li t0, MSTATUS_GVA
  csrs mstatus, t0          /* preset GVA=1 so the trap must clear it */
  ENTER_VS(vs_code)

vs_code:
  .word 0xffffffff          /* illegal instruction */
  FAIL(2)                   /* should not get here */

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 2
  bne t0, t1, bad_cause
  csrr t0, mstatus
  li t1, MSTATUS_MPV
  and t2, t0, t1
  beqz t2, no_mpv           /* trap must come from V=1 */
  li t1, MSTATUS_GVA
  and t2, t0, t1
  bnez t2, gva_set
  PASS
bad_cause:
  FAIL(3)
no_mpv:
  FAIL(4)
gva_set:
  FAIL(1)
