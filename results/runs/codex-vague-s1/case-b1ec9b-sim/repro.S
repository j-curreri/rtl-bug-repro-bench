#include "test.h"

/* MRET to a mode below M must clear mstatus.MPRV, even without H.
 * Take an undelegated S-mode ECALL immediately afterward. Trap entry does
 * not change MPRV, so the M-mode handler can inspect the result directly.
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

  /* Disable interrupts and select MPP=S, MPIE=0, MPRV=1. */
  li t0, ((3 << 11) | (1 << 17) | (1 << 7) | (1 << 3))
  csrc mstatus, t0
  li t0, ((1 << 11) | (1 << 17))
  csrs mstatus, t0

  /* Confirm that the precondition really holds. No data accesses follow. */
  csrr t1, mstatus
  and t1, t1, t0
  bne t1, t0, setup_failed
  la t0, supervisor_ecall
  csrw mepc, t0
  mret

supervisor_ecall:
  ecall
  j unexpected_trap

  .balign 4
  .globl trap_handler
trap_handler:
  csrr t2, mstatus
  /* Clear MPRV before any eventual tohost store, preserving the snapshot. */
  li t0, (1 << 17)
  csrc mstatus, t0

  csrr t1, mcause
  li t3, 9                       /* Environment call from S-mode. */
  bne t1, t3, unexpected_trap
  csrr t1, mepc
  la t3, supervisor_ecall
  bne t1, t3, unexpected_trap

  and t2, t2, t0
  bnez t2, mprv_not_cleared
  PASS

mprv_not_cleared:
  FAIL(1)
setup_failed:
  li t0, (1 << 17)
  csrc mstatus, t0
  FAIL(2)
unexpected_trap:
  FAIL(3)
