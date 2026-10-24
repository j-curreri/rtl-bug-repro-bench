#include "test.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  csrw satp, zero
  /* Set MPRV=1, MPP=S, then mret to S-mode: MPRV must be cleared. */
  li t0, (1 << 17)
  csrs mstatus, t0
  csrr t1, mstatus
  and t1, t1, t0
  beqz t1, skip_fail        /* MPRV not writable?  (should be) */
  ENTER_MODE(1, s_code)

s_code:
  ecall                     /* back to M-mode */

m_after:
  csrr t1, mstatus
  li t0, (1 << 17)
  and t1, t1, t0
  bnez t1, fail
  PASS
fail:
  FAIL(1)
skip_fail:
  FAIL(2)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 9                  /* ecall from S */
  bne t0, t1, bad_trap
  la t0, m_after
  csrw mepc, t0
  li t0, (3 << 11)
  csrs mstatus, t0          /* MPP=M so mret stays in M */
  mret
bad_trap:
  FAIL(3)
