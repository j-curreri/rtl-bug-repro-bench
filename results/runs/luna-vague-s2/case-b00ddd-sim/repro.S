#include "hyp.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Map the DRAM containing the guest and its stack through G-stage. */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  /* Map guest code and a 4 GiB VA to the same unmapped GPA. */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  GIGA_LEAF(vs_root, 4, 0x100000000, VS_RWX)
  HGATP_ON

  la t0, vs_root
  VSATP_ON(t0)
  ENTER_VS(guest)

  /* Should only be reached if the expected guest page fault did not occur. */
  FAIL(1)

  .align 2
guest:
  li t0, 0x100000000
  ld t1, 0(t0)              /* G-stage fault on the translated load */
  FAIL(2)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 21                 /* Load guest-page fault */
  bne t0, t1, trap_fail

  /* mtval reports the faulting guest virtual address. */
  csrr t0, mtval
  li t1, 0x100000000
  bne t0, t1, trap_fail

  /* mtval2 reports the guest physical address shifted right by two. */
  csrr t0, mtval2
  li t1, 0x40000000
  bne t0, t1, trap_fail

  /* For an explicit LD, mtinst is the transformed instruction: rs1/immediate zero. */
  csrr t0, mtinst
  li t1, 0x3303
  bne t0, t1, trap_fail

  /* A trap from V=1 must record that virtualization was active in MPV. */
  csrr t0, mstatus
  srli t0, t0, 39
  andi t0, t0, 1
  beqz t0, trap_fail

  csrr t0, mstatus
  srli t0, t0, 38
  andi t0, t0, 1
  beqz t0, trap_fail

  PASS
trap_fail:
  FAIL(3)

  HYP_TABLES
