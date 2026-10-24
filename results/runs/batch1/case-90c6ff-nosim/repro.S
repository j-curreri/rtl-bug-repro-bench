#include "harness/hyp.h"
.text
.globl test_main
test_main:
  PMP_ALLOW_ALL
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 258, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 514, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 1026, 0x80000000, G_RWX)
  HGATP_ON
  csrw vsatp, zero
  ENTER_VS(vs_code)
.align 2
vs_code:
  la t2, tgt
  li t3, 0x3fffffff
  and t2, t2, t3
  li t3, 1
  slli t3, t3, 38
  or t4, t2, t3
  jalr ra, 0(t4)
  li t3, 1
  slli t3, t3, 39
  or t4, t2, t3
  jalr ra, 0(t4)
  li t3, 1
  slli t3, t3, 40
  or t4, t2, t3
  jalr ra, 0(t4)
  li a0, 1
  j _halt
.align 2
tgt:
  ret
HYP_TABLES
