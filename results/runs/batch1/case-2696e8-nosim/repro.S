#include "harness/hyp.h"
.text
.global test_main
.global trap_handler
test_main:
  PMP_ALLOW_ALL
  la t0, trap_handler
  csrw mtvec, t0
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 1, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A | PTE_D))
  csrw vsatp, zero
  HGATP_ON
  li s1, 0
  ENTER_MODE(1, smode)
smode:
  li t2, 0x40000000
  hlvx.wu t3, (t2)
  li s1, 1
  hlv.w t4, (t2)
  FAIL(2)
.align 2
trap_handler:
  csrr t0, mcause
  li t1, 21
  bne t0, t1, bad
  beqz s1, bad
  PASS
bad:
  FAIL(1)
HYP_TABLES
