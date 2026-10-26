#include "hyp.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Map the DRAM containing the program as one 1 GiB guest-physical page. */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  HGATP_ON

  /* Identity-map that same DRAM through the VS-stage page table. */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  la t0, vs_root
  VSATP_ON(t0)

  /* This instruction must trap from VS to M with cause=illegal instruction. */
  ENTER_VS(vs_illegal)

  .align 2
vs_illegal:
  .4byte 0x00000000
1: j 1b

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 2
  bne t0, t1, trap_fail

  csrr t0, mstatus
  srli t0, t0, 38
  andi t0, t0, 1
  bnez t0, trap_fail

  PASS
trap_fail:
  FAIL(1)

  HYP_TABLES
