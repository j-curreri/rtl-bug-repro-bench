#include "test.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  /* Keep all traps visible at M-mode except U-mode ECALL, delegated below. */
  la t0, m_trap
  csrw mtvec, t0
  la t0, s_trap
  csrw stvec, t0
  PMP_ALLOW_ALL

  /* A U-mode ECALL must update sepc/scause/stval when delegated to S-mode. */
  li t0, (1 << 8)
  csrw medeleg, t0
  ENTER_MODE(0, u_test)

u_test:
u_ecall:
  ecall
  /* Reaching this instruction means the S-mode handler returned incorrectly. */
  FAIL(1)

  .align 2
s_trap:
  /* The U-mode ECALL is cause 8, with sepc at the ECALL and stval zero. */
  csrr t0, scause
  li t1, 8
  bne t0, t1, s_bad_cause
  csrr t0, sepc
  la t1, u_ecall
  bne t0, t1, s_bad_epc
  csrr t0, stval
  bnez t0, s_bad_tval

  /* Now take a synchronous S-mode ECALL to M-mode and check its trap CSRs. */
s_ecall:
  ecall
  FAIL(2)

s_bad_cause:
  FAIL(3)
s_bad_epc:
  FAIL(4)
s_bad_tval:
  FAIL(5)

  .align 2
m_trap:
  /* Only the deliberate S-mode ECALL should reach M-mode. */
  csrr t0, mcause
  li t1, 9
  bne t0, t1, m_bad_cause
  csrr t0, mepc
  la t1, s_ecall
  bne t0, t1, m_bad_epc
  csrr t0, mtval
  bnez t0, m_bad_tval
  PASS

m_bad_cause:
  FAIL(6)
m_bad_epc:
  FAIL(7)
m_bad_tval:
  FAIL(8)
