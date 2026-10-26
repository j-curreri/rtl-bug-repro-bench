#include "hyp.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Map the DRAM region containing the guest code and VS page table. */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)

  HGATP_ON
  la t0, vs_root
  VSATP_ON(t0)

  /* The guest's load from VA 0xc0000000 maps to GPA 0xc0000000 via the
     VS-stage superpage, but G-stage index 3 is intentionally invalid. */
  ENTER_VS(vs_start)

  .align 2
vs_start:
  li t0, 0xc0000000
  ld t1, 0(t0)
  FAIL(2)                    /* The load must raise a guest-page fault. */

  .align 2
  .globl trap_handler
trap_handler:
  /* Load guest-page fault, with mtval containing the GVA and mtval2 the
     faulting GPA shifted right by two as specified by the H extension. */
  csrr t0, mcause
  li t1, 21                  /* Load guest-page fault. */
  bne t0, t1, fail_trap

  csrr t0, mtval
  li t1, 0xc0000000
  bne t0, t1, fail_trap

  csrr t0, mtval2
  li t1, 0x30000000
  bne t0, t1, fail_trap

  csrr t0, mstatus
  li t1, (1 << 38) | (1 << 39) /* GVA and MPV */
  and t0, t0, t1
  bne t0, t1, fail_trap

  PASS
fail_trap:
  FAIL(1)

  HYP_TABLES
