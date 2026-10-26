#include "hyp.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Map DRAM at 0x80000000 identically through G-stage. */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  HGATP_ON

  /* The code runs in the 1 GiB VS mapping at 0x80000000.  VA 0x40000000
   * instead uses a valid non-leaf PTE whose PPN encodes GPA 2^41, outside
   * the Sv39x4 guest-physical address space. */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  RAW_PTE(vs_root, 1, 0x8000000001)

  la t0, vs_root
  VSATP_ON(t0)
  ENTER_VS(vs_start)

  .align 2
vs_start:
  li t0, 0x40000000
  ld t1, 0(t0)
  /* The access must fault. Reaching here means translation accepted the
   * out-of-range page-table pointer. */
  FAIL(1)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 21                 /* load guest-page fault */
  beq t0, t1, 1f
  FAIL(2)
1:
  PASS

  HYP_TABLES
