#include "test.h"

#define MIP_SSIP (1 << 1)

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* ---- Test A: M-mode interrupt taken in M-mode ---- */
  li s0, 1                 /* phase */
  li t0, 0x1234
  csrw mtval, t0
  li t0, MIP_SSIP
  csrw mie, t0
  csrsi mstatus, 8         /* MIE */
  csrs mip, t0             /* raise SSIP, not delegated -> M */
  nop
  nop
  nop
  nop
after_a:
  li t0, 2
  bne s0, t0, fail_noint_a
  csrci mstatus, 8
  csrw mie, zero

  /* ---- Test B: interrupt delegated to S-mode ---- */
  li t0, 0x5678
  csrw stval, t0
  li t0, MIP_SSIP
  csrw mideleg, t0
  csrw mie, t0
  la t0, s_handler
  csrw stvec, t0
  li t0, 2                 /* SIE */
  csrs mstatus, t0
  li s0, 3
  ENTER_MODE(1, s_code)
s_code:
  li t0, MIP_SSIP
  csrs sip, t0
  nop
  nop
  nop
  nop
  FAIL(20)
s_done:
  PASS

fail_noint_a:
  FAIL(10)

  .align 2
s_handler:
  csrr t1, scause
  li t2, (1 << 63) | 1
  bne t1, t2, f21
  csrr t1, stval
  bnez t1, f22
  csrr t1, sepc
  la t2, s_code
  bltu t1, t2, f25
  la t2, s_done
  bgeu t1, t2, f25
  j s_done
f21: FAIL(21)
f22: FAIL(22)
f23: FAIL(23)
f24: FAIL(24)
f25: FAIL(25)

  .align 2
  .globl trap_handler
trap_handler:
  li t2, 1
  bne s0, t2, f9
  csrr t1, mcause
  li t2, (1 << 63) | 1
  bne t1, t2, f11
  csrr t1, mtval
  bnez t1, f12
  csrr t1, mepc
  la t2, test_main
  bltu t1, t2, f15
  la t2, after_a
  bgtu t1, t2, f15
  csrr t1, mstatus
  srli t2, t1, 11
  andi t2, t2, 3
  li t3, 3
  bne t2, t3, f16
  andi t2, t1, 0x80        /* MPIE */
  beqz t2, f17
  andi t2, t1, 8           /* MIE cleared */
  bnez t2, f18
  li t0, MIP_SSIP
  csrc mip, t0
  li s0, 2
  li t0, 0x80
  csrc mstatus, t0          /* return with MIE=0 */
  mret
f9:  csrr t6, mcause
     FAIL(9)
f11: FAIL(11)
f12: FAIL(12)
f13: FAIL(13)
f14: FAIL(14)
f15: FAIL(15)
f16: FAIL(16)
f17: FAIL(17)
f18: FAIL(18)
