#include "hyp.h"
  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* G-stage: GPA 2G -> PA 2G RWX; GPA 4G -> PA 2G execute-only (alias) */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 4, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A | PTE_D))
  /* VS-stage: VA 2G -> GPA 2G, RWX */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  HGATP_ON
  la t2, vs_root
  li t3, 0x80000000
  add t2, t2, t3        /* alias GPA of vs_root (execute-only in G-stage) */
  VSATP_ON(t2)
  la t0, trap_handler2
  csrw mtvec, t0
  li t0, HSTATUS_SPVP
  csrs hstatus, t0
  li a1, 0x80000000
  hlvx.hu a2, (a1)
  FAIL(1)
  .align 2
trap_handler2:
  csrr t0, mcause
  li t1, 21
  bne t0, t1, 1f
  PASS
1: FAIL(2)
  HYP_TABLES
