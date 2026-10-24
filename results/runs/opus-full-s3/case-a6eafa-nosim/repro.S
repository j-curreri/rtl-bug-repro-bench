/* HLVX with a VS-stage page table located in guest-physical memory that the
 * G-stage maps execute-only. The implicit VS-stage PTE read is a load for the
 * G-stage check, so it must raise a load guest-page fault (cause 21). */
#include "hyp.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* G-stage: GPA 0x80000000 (1 GiB) -> PA 0x80000000, RWX.
   *          GPA 0xC0000000 (1 GiB) -> PA 0x80000000, execute-only. */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 3, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A))

  /* VS-stage: VA 0x80000000 -> GPA 0x80000000, RWX. */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)

  HGATP_ON

  /* vsatp root = GPA alias of vs_root inside the execute-only region. */
  la t2, vs_root
  li t0, 0x40000000
  add t2, t2, t0
  VSATP_ON(t2)

  /* Effective privilege for HLVX: VS-mode. Keep MXR clear. */
  li t0, HSTATUS_SPVP
  csrs hstatus, t0
  li t0, (1 << 19)
  csrc mstatus, t0

  la a1, target_data
  hlvx.hu a2, (a1)
  /* Reaching here means the walk succeeded: bug. */
  FAIL(1)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 21
  bne t0, t1, 1f
  PASS
1:
  FAIL(2)

  .data
  .align 4
target_data:
  .half 0x1234
  .half 0x5678

  HYP_TABLES
