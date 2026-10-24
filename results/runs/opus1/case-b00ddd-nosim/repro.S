/* Illegal instruction in VS-mode, offloaded to CV-X-IF and rejected by the
 * coprocessor, must trap to M-mode with mstatus.GVA = 0 (mtval is not a GVA). */
#include "hyp.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  csrw medeleg, zero
  csrw hedeleg, zero
  csrw mideleg, zero
  /* G-stage: identity map GPA 0x80000000 (1 GiB). VS-stage stays bare. */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  HGATP_ON
  csrw vsatp, zero
  li t0, MSTATUS_GVA
  csrc mstatus, t0
  ENTER_VS(guest)

  .align 2
guest:
  .word 0x0000000b      /* custom-0: not decoded by the core, rejected by coprocessor */
  FAIL(1)               /* illegal instruction did not trap */

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 2
  bne t0, t1, bad_cause
  csrr t0, mstatus
  li t1, MSTATUS_MPV
  and t2, t0, t1
  beqz t2, not_virt
  li t1, MSTATUS_GVA
  and t2, t0, t1
  bnez t2, gva_set
  PASS
bad_cause:
  FAIL(2)
not_virt:
  FAIL(3)
gva_set:
  FAIL(4)

  HYP_TABLES
