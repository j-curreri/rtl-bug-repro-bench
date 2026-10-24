#include "harness/hyp.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* G-stage: GPA 0x80000000 and GPA 0x4000000000 (index 256, bit 38) both -> PA 0x80000000 */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 256, 0x80000000, G_RWX)
  HGATP_ON
  csrw vsatp, zero
  /* VS-mode entry at the high GPA alias of vs_code */
  li t0, MSTATUS_MPV
  csrs mstatus, t0
  li t0, (3 << 11)
  csrc mstatus, t0
  li t0, (1 << 11)
  csrs mstatus, t0
  la t0, vs_code
  li t1, 0x4000000000
  add t0, t0, t1
  li t1, 0x80000000
  sub t0, t0, t1
  csrw mepc, t0
  mret

vs_code:
  ecall

  .align 2
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  li t5, 10            /* ecall from VS-mode */
  bne t6, t5, 1f
  PASS
1:
  FAIL(1)

  HYP_TABLES
