#include "hyp.h"

/* Bug: after an HLVX read through an execute-only G-stage page, a plain HLV load from the
 * same page still succeeds (the G-TLB hit path does not re-check R for loads).
 *
 * Setup: G-stage gigapage GPA[0,1G) -> PA 0x80000000 with X|U|A|D but no R. VS-stage is Bare,
 * so guest VA == GPA. The test page is GPA 0x200000 (PA 0x80200000).
 * Correct core: HLVX.HU reads the halfword, HLV.D raises a load guest-page fault (mcause 21).
 * Buggy core: HLV.D completes without a trap, so execution falls through to FAIL. */

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Seed the test page through physical addresses (M-mode, no translation). */
  li t0, 0x80200000
  li t1, 0x1122334455667788
  sd t1, 0(t0)

  /* G-stage: execute-only (no R) user-accessible gigapage covering GPA 0..1 GiB. */
  GIGA_LEAF(g_root, 0, 0x80000000, PTE_V | PTE_X | PTE_U | PTE_A | PTE_D)
  HGATP_ON

  /* vsatp = Bare (reset value 0) so guest VA == GPA. */
  csrw vsatp, zero
  hfence.vvma

  li s0, 0                 /* s0 = 1 once the HLVX read has succeeded */
  ENTER_MODE(1, hs_code)   /* HS-mode, MPV = 0 */

hs_code:
  li a0, 0x200000
  hlvx.hu a1, (a0)         /* must succeed: execute permission counts as read for HLVX */
  li t0, 0x7788
  bne a1, t0, 1f
  li s0, 1

  hlv.d a2, (a0)           /* must raise a load guest-page fault on a correct core */
  FAIL(3)                  /* reached only if the plain HLV load wrongly succeeded */
1:
  FAIL(4)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 21                /* load guest-page fault */
  bne t0, t1, 2f
  li t1, 1
  bne s0, t1, 2f           /* the HLVX read must have happened first */
  PASS
2:
  FAIL(2)

HYP_TABLES
