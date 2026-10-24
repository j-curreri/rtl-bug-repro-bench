/* Repro for: VS-mode two-stage translation, VS-stage walk reaches a non-leaf
 * PTE whose PPN points outside the 41-bit guest-physical address space.
 * The spec requires a load guest-page fault (mcause 21) for the load.
 *
 * tohost encoding used to diagnose what happens:
 *   1          -> PASS: HS-mode trap, mcause == 21 (load guest-page fault)
 *   5|C<<4     -> HS-mode trap with wrong cause C
 *   9 | 32*G   -> no trap at all; G = 1 if hgatp still in Sv39x4 mode
 *   255        -> M-mode trap (default handler)
 */
#include "test.h"
#include "hyp.h"

  HYP_TABLES

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* G-stage: 1 GiB identity map of DRAM. */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  HGATP_ON

  /* VS-stage root. */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  RAW_PTE(vs_root, 5, (0x20000000 << 10) | PTE_V)

  la t0, vs_root
  VSATP_ON(t0)

  la t0, hs_trap
  csrw stvec, t0

  ENTER_VS(vs_main)

  /* Unreachable: trap goes to HS-mode. */
  FAIL(3)

vs_main:
  csrr t0, hgatp      /* diagnostic: is G-stage still on? */
  li   t1, 9          /* a0 base = FAIL(4) */
  srli t0, t0, 60
  li   t2, 8
  bne  t0, t2, 1f
  ori  t1, t1, 32     /* bit: hgatp still enabled */
1: li a0, t1
  li t0, 0xA0000000
  ld t1, 0(t0) /* traps on a correct setup: walk hits the bad non-leaf PTE */
  j  _halt      /* no trap: a0 already holds 9 | diag */

/* The faulting load runs in VS-mode, so the trap is delivered to HS-mode.
 * Correct core: mcause = 21 (load guest-page fault). */
hs_trap:
  .align 2
  csrr t0, mcause
  li t1, 21
  bne t0, t1, hs_trap_fail
  la t0, tohost
  li t1, 1 /* PASS */
  sd t1, 0(t0)
1: j 1b
hs_trap_fail:
  /* encode the wrong cause: tohost = 5 | (cause << 4) */
  slli t0, t0, 4
  li t1, 5
  or t0, t0, t1
  la t1, tohost
  sd t0, 0(t1)
2: j 2b
