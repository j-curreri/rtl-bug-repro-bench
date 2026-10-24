#include "hyp.h"

/* G-stage on, vsatp = Bare. VS-mode fetches from GPA 0x40_8000_0000 + off
 * (bit 38 set, bits 63:41 zero), a valid Sv39x4 GPA mapped to DRAM. */
#define HI_GPA_OFF 0x4000000000

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  csrw medeleg, zero
  csrw hedeleg, zero
  csrw mideleg, zero
  csrw vsatp, zero
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)       /* GPA 0x0_8000_0000 */
  GIGA_LEAF(g_root, 0x102, 0x80000000, G_RWX)   /* GPA 0x40_8000_0000 */
  HGATP_ON
  li t0, MSTATUS_MPV
  csrs mstatus, t0
  li t0, (3 << 11)
  csrc mstatus, t0
  li t0, (1 << 11)
  csrs mstatus, t0
  la t0, vs_code
  li t1, HI_GPA_OFF
  add t0, t0, t1
  csrw mepc, t0
  mret

  .align 2
vs_code:
  li a1, 0x5a
vs_ecall:
  ecall
1: j 1b

  .align 2
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  li t5, 10                 /* ecall from VS */
  bne t6, t5, bad
  li t5, 0x5a
  bne a1, t5, bad
  csrr t4, mepc
  la t3, vs_ecall
  li t1, HI_GPA_OFF
  add t3, t3, t1
  bne t4, t3, bad
  PASS
bad:
  li t5, 20                 /* instruction guest-page fault */
  beq t6, t5, f2
  li t5, 12                 /* instruction page fault */
  beq t6, t5, f3
  FAIL(1)
f2: FAIL(2)
f3: FAIL(3)

  HYP_TABLES
