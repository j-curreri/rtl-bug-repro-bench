#include "harness/hyp.h"
.text
.globl test_main
.globl trap_handler
test_main:
  PMP_ALLOW_ALL
  /* G-stage: GPA 0x4000000000 (bit 38) -> PA 0x80000000 */
  GIGA_LEAF(g_root, 256, 0x80000000, G_RWX)
  HGATP_ON
  csrw vsatp, zero
  li t0, MSTATUS_MPV
  csrs mstatus, t0
  li t0, (3 << 11)
  csrc mstatus, t0
  li t0, (1 << 11)
  csrs mstatus, t0
  la t0, vs_code
  li t1, 0x3fffffff
  and t0, t0, t1
  li t1, 0x4000000000
  or t0, t0, t1
  csrw mepc, t0
  mret
vs_code:
  ecall
  FAIL(2)
.align 2
trap_handler:
  csrr t0, mcause
  li t1, 10
  bne t0, t1, 1f
  PASS
1:
  FAIL(1)
HYP_TABLES
