/* VS-mode instruction fetch at a guest-physical address with bit 38 set, with
 * G-stage (Sv39x4) on and vsatp = Bare. GPAs are 41-bit and zero-extended, so
 * 0x40_8000_0000+ is a valid GPA and must be fetchable even though it is not an
 * Sv39-canonical virtual address. */
#include "hyp.h"

#define ALIAS 0x4000000000     /* GPA bit 38: g_root[0x102] -> DRAM gigapage */

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* G-stage: identity map the DRAM gigapage and alias it at GPA + 2^38. */
  GIGA_LEAF(g_root, 2,     0x80000000, G_RWX)
  GIGA_LEAF(g_root, 0x102, 0x80000000, G_RWX)

  csrw vsatp, zero
  csrw medeleg, zero
  csrw hedeleg, zero
  HGATP_ON

  li s0, 0
  ENTER_VS(vs_entry)

  .align 2
vs_entry:
  /* Jump to the alias of hi_stub, which returns to back1. */
  la s1, back1
  la t0, hi_stub
  li t1, ALIAS
  add t0, t0, t1
  jr t0
back1:
  ecall

  /* Executed through the high GPA alias. */
  .align 2
hi_stub:
  addi s0, s0, 1
  jr s1

  .align 2
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  li t5, 10              /* environment call from VS-mode */
  bne t6, t5, 1f
  li t5, 1
  bne s0, t5, 2f
  PASS
1:
  FAIL(1)
2:
  FAIL(2)


  HYP_TABLES
