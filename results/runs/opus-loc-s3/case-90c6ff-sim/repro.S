/* Reproducer: DTLB hit path skips the VS-stage read-permission re-check.
 *
 * VS-stage maps VA 0x1_0000_0000 to an execute-only page (R=0, X=1).
 * HLVX.WU from it is legal (execute permission suffices) and fills the DTLB.
 * A following plain HLV.W from the same address needs read permission and
 * must raise a load page fault (cause 13). The buggy core hits in the DTLB
 * and lets the load through. The same access without a prior HLVX faults
 * correctly through the page-table walker.
 */
#include "hyp.h"
  .option norvc
  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* G-stage: identity 1 GiB at GPA 0x80000000 */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  /* VS-stage: VA 0x80000000 -> GPA 0x80000000 RWX, VA 0x100000000 -> GPA 0x80000000 X-only */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  GIGA_LEAF(vs_root, 4, 0x80000000, (PTE_V | PTE_X | PTE_A))
  HGATP_ON
  la t2, vs_root
  VSATP_ON(t2)
  /* HLV/HLVX from M-mode access as VS-mode (SPVP=1) */
  li t0, HSTATUS_SPVP
  csrs hstatus, t0
  li t0, (1 << 19)          /* mstatus.MXR = 0 */
  csrc mstatus, t0
  li s1, 0                  /* fault expected flag */
  li s2, 0                  /* fault seen flag */

  la t2, data
  li t3, 0x80000000
  sub t2, t2, t3
  li t3, 0x100000000
  add t2, t2, t3            /* alias of `data` through the X-only page */

  hlvx.wu a1, (t2)          /* legal: execute permission, fills DTLB */
  li s1, 1
  hlv.w a2, (t2)            /* needs read permission: must fault */
  li s1, 0

  li t0, 1
  bne s2, t0, 1f
  PASS
1:
  FAIL(3)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  beqz s1, 2f
  li t5, 13                 /* load page fault */
  bne t6, t5, 2f
  li s2, 1
  csrr t5, mepc
  addi t5, t5, 4
  csrw mepc, t5
  mret
2:
  FAIL(4)

  HYP_TABLES
  .align 3
data: .dword 0x1234
