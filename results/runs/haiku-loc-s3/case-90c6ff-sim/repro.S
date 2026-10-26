#include "hyp.h"

/* Reproducer: a plain HLV load that hits in the DTLB after an HLVX read of the same
 * execute-only page must raise a load page fault (13) at the hlv.d instruction.
 *
 * Setup: HS-mode, Sv39 VS-stage over Sv39x4 G-stage (1 GiB leaves only).
 * - VS page at VA 0x40000000 maps to GPA 0xC0000000 with X=1, R=0, U=0 (execute-only).
 * - vsstatus.MXR = 0, so only HLVX may read it.
 * 1. HLVX.HU reads it. The spec allows this, and the translation is cached in the DTLB.
 * 2. HLV.D reads it with plain HLV. The spec requires a load page fault. The buggy core
 *    hits the cached entry and skips the S-stage read check, so the load succeeds.
 */
  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 3, 0x80000000, G_RWX)
  GIGA_LEAF(vs_root, 1, 0xC0000000, 0xC9)   /* V X A D: no R, no U */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  HGATP_ON
  la t2, vs_root
  VSATP_ON(t2)
  li t0, HSTATUS_SPVP
  csrs hstatus, t0
  ENTER_MODE(1, hs_code)

hs_code:
  li s0, 0x40000000
  hlvx.hu t0, (s0)
  hlv_pc:
  hlv.d t1, (s0)
  FAIL(2)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t6, mcause
  li t5, 13
  bne t6, t5, 1f
  la t4, hlv_pc
  csrr t3, mepc
  bne t3, t4, 1f
  PASS
1: FAIL(3)

  HYP_TABLES
