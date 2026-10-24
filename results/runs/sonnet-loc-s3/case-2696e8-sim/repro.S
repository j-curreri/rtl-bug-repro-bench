#include "hyp.h"
  .text
  .globl test_main
  .globl trap_handler
test_main:
  PMP_ALLOW_ALL
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 1, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A))
  HGATP_ON
  csrw vsatp, zero
  csrw hstatus, zero
  li s0, 0x40000000
  li s1, 0
  hlvx.hu t2, (s0)
  bnez s1, fail1
  hlv.hu t2, (s0)
  li t0, 1
  bne s1, t0, fail2
  PASS
fail1: FAIL(1)
fail2: FAIL(2)

  .align 2
trap_handler:
  csrr t6, mcause
  li t5, 21
  bne t6, t5, bad
  addi s1, s1, 1
  csrr t5, mepc
  addi t5, t5, 4
  csrw mepc, t5
  mret
bad: FAIL(3)
HYP_TABLES
