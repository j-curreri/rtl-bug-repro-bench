#include "test.h"

/* Take interrupts in M-mode and in (delegated) S-mode and check the trap CSRs:
 * xcause = interrupt bit | code, xepc = interrupted instruction, xtval = 0,
 * xPIE/xPP/xIE updated as the privileged spec requires. */

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  csrw mideleg, zero
  csrw medeleg, zero
  csrw mtval, zero
  csrw stval, zero

  /* ---------- Phase 1: supervisor software interrupt taken in M ---------- */
  li t0, 2
  csrw mie, t0              /* SSIE */
  csrsi mstatus, 8          /* MIE */
  li t0, 2
  la s11, check_m
m_int:
  csrs mip, t0              /* raise SSIP -> trap */
  nop
  nop
  nop
m_int_end:
  j m_noint
check_m:
  li t0, (1 << 63) | 1
  bne s0, t0, f1
  bnez s1, f2
  la t0, m_int
  bltu s2, t0, f3
  la t0, m_int_end
  bgtu s2, t0, f3
  srli t0, s3, 7            /* MPIE */
  andi t0, t0, 1
  beqz t0, f4
  srli t0, s3, 11           /* MPP == M */
  andi t0, t0, 3
  li t1, 3
  bne t0, t1, f5
  andi t0, s3, 8            /* MIE cleared */
  bnez t0, f6

  /* ---------- Phase 2: SSIP delegated to S-mode, taken in S ---------- */
  li t0, 2
  csrw mideleg, t0
  la t0, s_handler
  csrw stvec, t0
  csrci sstatus, 2
  li t0, 2
  csrw mie, t0
  csrs mip, t0              /* pending, not taken in M */
  ENTER_MODE(1, s_code)
s_code:
s_int:
  csrsi sstatus, 2          /* SIE -> trap */
  nop
  nop
  nop
s_int_end:
  j s_noint

  .align 2
s_handler:
  csrr s0, scause
  csrr s1, stval
  csrr s2, sepc
  csrr s3, sstatus
  csrci sip, 2
  li t0, (1 << 63) | 1
  bne s0, t0, f11
  bnez s1, f12
  la t0, s_int
  bltu s2, t0, f13
  la t0, s_int_end
  bgtu s2, t0, f13
  andi t0, s3, 0x20         /* SPIE */
  beqz t0, f14
  andi t0, s3, 0x100        /* SPP = S */
  beqz t0, f15
  andi t0, s3, 2            /* SIE cleared */
  bnez t0, f16
  PASS

  /* ---------- M-mode trap handler ---------- */
  .align 2
  .globl trap_handler
trap_handler:
  csrr t5, mcause
  bltz t5, 2f
  FAIL(100)
2:
  bnez s11, 3f
  FAIL(101)                 /* unexpected interrupt */
3:
  csrr s0, mcause
  csrr s1, mtval
  csrr s2, mepc
  csrr s3, mstatus
  li t0, 2
  csrc mip, t0
  mv t0, s11
  li s11, 0
  jr t0

m_noint: FAIL(9)
s_noint: FAIL(19)
f1: FAIL(1)
f2: FAIL(2)
f3: FAIL(3)
f4: FAIL(4)
f5: FAIL(5)
f6: FAIL(6)
f11: FAIL(11)
f12: FAIL(12)
f13: FAIL(13)
f14: FAIL(14)
f15: FAIL(15)
f16: FAIL(16)
