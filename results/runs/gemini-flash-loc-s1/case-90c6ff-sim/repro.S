#include "hyp.h"

.globl test_main
test_main:
  PMP_ALLOW_ALL

  // In g_root (Sv39x4, 16 KiB root table):
  // Map index 2 (GPA 0x80000000, 2 GiB) -> PA 0x80000000 (identity mapping for DRAM)
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)

  // Map index 512 (GPA 0x8000000000, 512 GiB, bit 39 = 1) -> PA 0x80000000
  GIGA_LEAF(g_root, 512, 0x80000000, G_RWX)

  // Enable G-stage translation (Sv39x4)
  HGATP_ON

  // Set VS-stage translation to Bare mode (vsatp = 0)
  csrw vsatp, zero
  hfence.vvma

  // Calculate target address for vs_code at GPA 0x80_0000_0000
  li t0, 0x8000000000
  la t1, vs_code
  li t2, 0x3fffffff
  and t1, t1, t2
  or t0, t0, t1

  // Enter VS-mode at GPA t0 (bit 39 set)
  li t1, MSTATUS_MPV
  csrs mstatus, t1
  li t1, (3 << 11)
  csrc mstatus, t1
  li t1, (1 << 11)
  csrs mstatus, t1
  csrw mepc, t0
  mret

vs_code:
  PASS

HYP_TABLES
