#include "test.h"

/*
 * Privileged ISA, MRET: when returning to a mode less privileged than M,
 * mstatus.MPRV is cleared.  This rule also applies when H is absent.
 *
 * The affected RTL puts this update inside `if (CVA6Cfg.RVH)`.  Enter S
 * with MPRV set, immediately ECALL back to M, and inspect the saved bit.
 * Trap entry changes MPP but does not change MPRV.
 */
  .section .text
  .balign 4
  .globl test_main
test_main:
  csrw mie, zero
  csrw medeleg, zero
  csrw mideleg, zero
  csrw satp, zero
  PMP_ALLOW_ALL

  /* No data accesses are needed between setting MPRV and the ECALL. */
  li t0, ((3 << 11) | (1 << 3) | (1 << 7))
  csrc mstatus, t0
  li t0, ((1 << 11) | (1 << 17))  /* MPP=S, MPRV=1 */
  csrs mstatus, t0
  la t0, supervisor_ecall
  csrw mepc, t0
  mret

supervisor_ecall:
  ecall
  j unexpected

  .balign 4
  .globl trap_handler
trap_handler:
  /* Clear MPRV before the harness stores to tohost, preserving a snapshot. */
  li t0, (1 << 17)
  csrrc t1, mstatus, t0
  csrr t2, mcause
  li t3, 9                       /* ECALL from S-mode */
  bne t2, t3, unexpected
  csrr t2, mepc
  la t3, supervisor_ecall
  bne t2, t3, unexpected
  and t1, t1, t0
  bnez t1, mprv_not_cleared
  PASS

mprv_not_cleared:
  FAIL(1)
unexpected:
  FAIL(2)
