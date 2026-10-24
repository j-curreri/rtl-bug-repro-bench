#include "test.h"

#define MSIP_ADDR 0x02000000

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* ---------- Test 1: M-mode software interrupt taken in M-mode ---------- */
  li s0, 1
  li t0, 0x1234
  csrw mtval, t0              /* stale nonzero value: must be overwritten with 0 */
  li t0, 8
  csrs mie, t0                /* MSIE */
  li t1, MSIP_ADDR
  li t0, 1
  sw t0, 0(t1)                /* raise MSIP */
  fence
  /* wait until pending is visible */
1: csrr t0, mip
  andi t0, t0, 8
  beqz t0, 1b
  csrsi mstatus, 8            /* MIE=1 -> interrupt taken before next insn */
m_int_epc:
  addi x0, x0, 0
  FAIL(1)                     /* should not get here; handler skips */
m_int_ret:

  /* ---------- Test 2: S-mode software interrupt delegated, taken in S ---------- */
  li s0, 2
  li t0, 2
  csrw mideleg, t0            /* delegate SSI */
  csrs mie, t0                /* SSIE */
  la t0, s_handler
  csrw stvec, t0
  li t0, 0x5678
  csrw stval, t0
  li t0, 2
  csrc mstatus, t0            /* SIE=0 */
  ENTER_MODE(1, s_code)
s_code:
  csrsi sip, 2                /* SSIP pending */
  csrsi sstatus, 2            /* SIE=1 -> trap */
s_int_epc:
  addi x0, x0, 0
  FAIL(20)
s_int_ret:
  /* ---------- Test 3: M timer-like: M software interrupt taken from S-mode ---- */
  li s0, 3
  li t1, MSIP_ADDR
  li t0, 1
  sw t0, 0(t1)                /* raise MSIP (M-mode int, taken regardless of MIE in S) */
s_wait:
  j s_wait                    /* interrupt arrives here; handler checks MPP */
s3_done:
  PASS

/* -------------------- S-mode handler (test 2) -------------------- */
  .align 2
s_handler:
  csrr t0, scause
  li t1, (1 << 63) | 1
  bne t0, t1, sfail21
  csrr t0, stval
  bnez t0, sfail22
  csrr t0, sepc
  la t1, s_int_epc
  bne t0, t1, sfail23
  csrr t0, sstatus
  andi t1, t0, 0x100          /* SPP */
  beqz t1, sfail24
  andi t1, t0, 0x20           /* SPIE */
  beqz t1, sfail25
  andi t1, t0, 0x2            /* SIE */
  bnez t1, sfail26
  csrci sip, 2
  la t0, s_int_ret
  csrw sepc, t0
  sret
sfail21: FAIL(21)
sfail22: FAIL(22)
sfail23: FAIL(23)
sfail24: FAIL(24)
sfail25: FAIL(25)
sfail26: FAIL(26)

/* -------------------- M-mode handler -------------------- */
  .align 2
  .globl trap_handler
trap_handler:
  /* clear MSIP */
  li t1, MSIP_ADDR
  sw zero, 0(t1)
  csrr t0, mcause
  li t1, (1 << 63) | 3
  bne t0, t1, mfail_cause
  csrr t0, mtval
  bnez t0, mfail_tval
  li t1, 1
  beq s0, t1, m_t1
  li t1, 3
  beq s0, t1, m_t3
  FAIL(9)

m_t1:
  csrr t0, mepc
  la t1, m_int_epc
  bne t0, t1, mfail_epc
  csrr t0, mstatus
  srli t1, t0, 11
  andi t1, t1, 3
  li t2, 3
  bne t1, t2, mfail_mpp
  andi t1, t0, 0x80           /* MPIE */
  beqz t1, mfail_mpie
  andi t1, t0, 0x8            /* MIE */
  bnez t1, mfail_mie
  /* return to m_int_ret with MIE=0 */
  li t0, 0x80
  csrc mstatus, t0
  la t0, m_int_ret
  csrw mepc, t0
  mret

m_t3:
  csrr t0, mepc
  la t1, s_wait
  bne t0, t1, mfail_epc3
  csrr t0, mstatus
  srli t1, t0, 11
  andi t1, t1, 3
  li t2, 1
  bne t1, t2, mfail_mpp3
  andi t1, t0, 0x8
  bnez t1, mfail_mie
  /* MPIE = previous MIE, which ENTER_MODE mret set to 1 */
  andi t1, t0, 0x80
  beqz t1, mfail_mpie3
  PASS

mfail_cause: FAIL(2)
mfail_tval:  FAIL(3)
mfail_epc:   FAIL(4)
mfail_mpp:   FAIL(5)
mfail_mpie:  FAIL(6)
mfail_mie:   FAIL(7)
mfail_epc3:  FAIL(10)
mfail_mpp3:  FAIL(11)
mfail_mpie3: FAIL(12)
