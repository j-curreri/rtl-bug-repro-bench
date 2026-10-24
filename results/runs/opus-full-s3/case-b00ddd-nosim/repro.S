/* mstatus.GVA must be 0 on an illegal-instruction trap taken from VS-mode into M-mode.
 * With CV-X-IF enabled, the decoder offloads illegal instructions to the coprocessor;
 * when it rejects them, cvxif_fu raises the exception with gva = V (bug). */
#include "hyp.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* Identity-map DRAM (GPA 0x80000000) in the G-stage; VS-stage stays bare. */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  HGATP_ON
  csrw vsatp, zero
  csrw medeleg, zero
  csrw hedeleg, zero
  /* Start with GVA set so a correct core must actively clear it. */
  li t0, MSTATUS_GVA
  csrs mstatus, t0
  ENTER_VS(vs_code)

vs_code:
  .word 0x7e000033      /* OP opcode, funct7=0x3f: illegal, not accepted by the coprocessor */
  j vs_code             /* not reached */

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 2              /* illegal instruction */
  bne t0, t1, bad_cause
  csrr t0, mstatus
  li t1, MSTATUS_MPV
  and t1, t0, t1
  beqz t1, bad_mpv      /* trap must come from V=1 */
  li t1, MSTATUS_GVA
  and t1, t0, t1
  bnez t1, bad_gva
  PASS
bad_cause:
  FAIL(1)
bad_mpv:
  FAIL(2)
bad_gva:
  FAIL(3)

  HYP_TABLES
