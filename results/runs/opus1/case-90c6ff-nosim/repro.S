/* G-stage on, vsatp = Bare: VS-mode fetch from guest-physical address
 * 0x1C0_0000_0000 (bits 40:38 set, valid in 41-bit Sv39x4 GPA space). A correct core
 * must not apply the Sv39 VA canonical check (bits 63:38 equal) here. */
#include "hyp.h"

#define GPA_HI 0x1C000000000

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* GPA 0x0_8000_0000 -> PA 0x8000_0000 (identity), GPA 0x1C0_0000_0000 -> PA 0x8000_0000 */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, (GPA_HI >> 30), 0x80000000, G_RWX)
  csrw vsatp, zero
  csrw hedeleg, zero
  csrw hideleg, zero
  csrw medeleg, zero
  HGATP_ON
  li t0, MSTATUS_MPV
  csrs mstatus, t0
  li t0, (3 << 11)
  csrc mstatus, t0
  li t0, (1 << 11)
  csrs mstatus, t0
  la t0, vs_code
  li t1, (GPA_HI - 0x80000000)
  add t0, t0, t1
  csrw mepc, t0
  mret

  .align 2
vs_code:
  li a1, 0x55
  ecall
  FAIL(3)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 10              /* environment call from VS-mode */
  bne t0, t1, 1f
  li t1, 0x55
  bne a1, t1, 2f
  PASS
1:
  FAIL(1)
2:
  FAIL(2)

  HYP_TABLES
