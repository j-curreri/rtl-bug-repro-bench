#include "harness/hyp.h"
.globl test_main
.text
test_main:
  PMP_ALLOW_ALL
  /* identity map 0x80000000 and alias at GPA 0x4000000000 (bit 38 set) */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 0x100, 0x80000000, G_RWX)
  HGATP_ON
  csrw vsatp, zero
  /* target = alias of vs_code */
  la t2, vs_code
  li t3, 0x4000000000
  li t4, 0x3fffffff
  and t2, t2, t4
  or t2, t2, t3
  li t0, MSTATUS_MPV
  csrs mstatus, t0
  li t0, (3 << 11)
  csrc mstatus, t0
  li t0, (1 << 11)
  csrs mstatus, t0
  csrw mepc, t2
  mret
vs_code:
  PASS
HYP_TABLES
