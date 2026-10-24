/* With only G-stage translation (vsatp=Bare), guest-physical fetch addresses need only bits
 * above GPLEN (41) to be zero, not Sv39 sign extension. VS-mode code at GPA 0x40_0000_0000
 * (bit 38 set) must run. */
#include "hyp.h"
#define GPA_HI 0x4000000000
  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  GIGA_LEAF(g_root, 0x100, 0x80000000, G_RWX)   /* GPA 0x40_0000_0000 -> 0x80000000 */
  HGATP_ON
  csrw vsatp, zero
  li t0, MSTATUS_MPV
  csrs mstatus, t0
  li t0, (3 << 11)
  csrc mstatus, t0
  li t0, (1 << 11)
  csrs mstatus, t0
  la t0, in_vs
  li t1, 0x80000000
  sub t0, t0, t1
  li t1, GPA_HI
  add t0, t0, t1
  csrw mepc, t0
  mret
in_vs:
  ecall

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 10                    /* ecall from VS-mode */
  bne t0, t1, 1f
  PASS
1: FAIL(1)

  HYP_TABLES
