#include "hyp.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  sfence.vma

  /* Trap all exceptions and interrupts directly to M-mode trap_handler */
  csrw medeleg, zero
  csrw mideleg, zero
  csrw hedeleg, zero
  csrw hideleg, zero

  /* Keep S-stage and VS-stage translation off (Bare) */
  csrw satp, zero
  csrw vsatp, zero
  hfence.vvma

  /*
   * Populate Sv39x4 G-stage root table (g_root has 2048 1-GiB entries,
   * covering 41-bit zero-extended GPAs 0x0000_0000_0000_0000 .. 0x0000_01ff_ffff_ffff).
   * Map DRAM (PA 0x80000000, 1 GiB) at:
   *   idx = 0x002 : GPA 0x0000_0000_8000_0000 (identity, bits [40:38] = 000)
   *   idx = 0x0ff : GPA 0x0000_003f_c000_0000 (below 2^38, bits [40:38] = 000)
   *   idx = 0x100 : GPA 0x0000_0040_0000_0000 (bit 38 = 1, bits [40:38] = 001)
   *   idx = 0x200 : GPA 0x0000_0080_0000_0000 (bit 39 = 1, bits [40:38] = 010)
   *   idx = 0x400 : GPA 0x0000_0100_0000_0000 (bit 40 = 1, bits [40:38] = 100)
   *   idx = 0x7ff : GPA 0x0000_01ff_c000_0000 (top GiB,   bits [40:38] = 111)
   */
  GIGA_LEAF(g_root, 0x002, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 0x0ff, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 0x100, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 0x200, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 0x400, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 0x7ff, 0x80000000, G_RWX)

  /* Enable Sv39x4 G-stage translation */
  HGATP_ON

  /* Compute target GPAs in s1..s5 = (PA & 0x3fffffff) | (idx << 30) */
  li t2, 0x3fffffff

  la s1, vs_step_0xff
  and s1, s1, t2
  li t3, 0x0000003fc0000000
  or s1, s1, t3

  la s2, vs_step_0x100
  and s2, s2, t2
  li t3, 0x0000004000000000
  or s2, s2, t3

  la s3, vs_step_0x200
  and s3, s3, t2
  li t3, 0x0000008000000000
  or s3, s3, t3

  la s4, vs_step_0x400
  and s4, s4, t2
  li t3, 0x0000010000000000
  or s4, s4, t3

  la s5, vs_step_0x7ff
  and s5, s5, t2
  li t3, 0x000001ffc0000000
  or s5, s5, t3

  li s0, 0
  ENTER_VS(vs_entry)

  .balign 4
vs_entry:
  ori s0, s0, 0x01
  jr s1

  .balign 4
vs_step_0xff:
  ori s0, s0, 0x02
  jr s2

  .balign 4
vs_step_0x100:
  ori s0, s0, 0x04
  jr s3

  .balign 4
vs_step_0x200:
  ori s0, s0, 0x08
  jr s4

  .balign 4
vs_step_0x400:
  ori s0, s0, 0x10
  jr s5

  .balign 4
vs_step_0x7ff:
  ori s0, s0, 0x20
  ecall
  j .

  .globl trap_handler
  .balign 4
trap_handler:
  /* Expect ECALL from VS-mode (mcause == 10) */
  csrr t0, mcause
  li t1, 10
  bne t0, t1, trap_unexpected_cause

  /* Expect all 6 VS-mode blocks to have executed */
  li t1, 0x3f
  bne s0, t1, fail_steps

  /* Expect mepc in 1 GiB region 0x7ff */
  csrr t0, mepc
  srli t0, t0, 30
  li t1, 0x7ff
  bne t0, t1, fail_mepc

  PASS

trap_unexpected_cause:
  li t1, 12
  beq t0, t1, fail_ipf
  FAIL(1)

fail_ipf:
  FAIL(12)

fail_steps:
  FAIL(2)

fail_mepc:
  FAIL(3)

  HYP_TABLES
