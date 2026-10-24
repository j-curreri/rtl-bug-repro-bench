/* Bug reproducer: traps taken from a virtualized mode into M-mode report
 * incorrect hypervisor trap information in the M-mode CSRs.
 *
 * Concretely, on a guest page fault the M-mode CSR mtval2 must hold the
 * guest physical address that caused the fault. This core instead stores
 * that address shifted right by two bits (mtval2 = tval2 >> 2).
 *
 * Scenario:
 *   - G-stage translation (Sv39x4) is enabled with a root table that maps
 *     only the 1 GiB region containing the program (0x80000000-0x8FFFFFFF,
 *     root index 2). The first 1 GiB region (root index 0) is unmapped.
 *   - No VS-stage translation (vsatp = 0), so guest physical address == GVA.
 *   - In VS-mode a double-load from 0x1008 faults in the G-stage:
 *       mcause = 21 (load guest page fault), taken into M-mode,
 *       mstatus.MPV = 1, mstatus.GVA = 1, mtval = 0x1008,
 *       mtval2 must be 0x1008 (the guest physical address).
 *   - On the buggy core mtval2 = 0x1008 >> 2 = 0x402 -> FAIL.
 *
 * Note: the PTE constant is written out explicitly because the local
 * binutils mis-evaluates multi-term hex OR expressions (drops 0x10).
 */
#include "hyp.h"
  HYP_TABLES
  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* g_root[2] = 1 GiB leaf: HPA = 0x80000000 | VA[11:0], PTE flags V|R|W|X|U|A|D. */
  RAW_PTE(g_root, 2, 0x200000FF)
  HGATP_ON
  ENTER_VS(vs_ld)

vs_ld:
  li t0, 0x1008
  ld a0, 0(t0)        /* G-stage load guest page fault -> trap into M-mode */
  j vs_ld

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mtval2
  li t1, 0x1008       /* guest physical address that caused the fault */
  bne t0, t1, fail
  PASS
fail:
  FAIL(1)
