#include "hyp.h"
.text
.globl test_main
test_main:
  la t0, trap_handler
  csrw mtvec, t0
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  HGATP_ON
  # entry0: NAPOT 8 bytes at g_root+0 (no perms); entry1: allow all
  la t0, g_root
  srli t0, t0, 2
  csrw pmpaddr0, t0
  li t0, -1
  csrw pmpaddr1, t0
  li t0, 0x1f1b
  csrw pmpcfg0, t0
  ENTER_VS(vs_code)
vs_code:
  li t0, 0x1000
  sd zero, 0(t0)
  FAIL(1)
.align 2
.globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 7
  bne t0, t1, 1f
  PASS
1:
  FAIL(2)
HYP_TABLES
