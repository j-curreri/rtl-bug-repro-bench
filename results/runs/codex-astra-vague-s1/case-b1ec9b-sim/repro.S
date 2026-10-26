#include "test.h"

/* MRET to S-mode must clear MPRV, including on cores without H.
 * An ECALL back to M-mode lets us read mstatus; trap entry itself does
 * not change MPRV.  No data accesses are needed while MPRV is set.
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

  /* Start with interrupts disabled and MPP=S, MPRV=1. */
  li t0, ((3 << 11) | (1 << 7) | (1 << 3) | (1 << 17))
  csrc mstatus, t0
  li t0, ((1 << 11) | (1 << 17))
  csrs mstatus, t0
  la t0, supervisor_entry
  csrw mepc, t0
  mret

supervisor_entry:
  ecall
  FAIL(1)

  .balign 4
  .globl trap_handler
trap_handler:
  /* Save the evidence, then clear MPRV before the harness stores tohost. */
  csrr t2, mstatus
  li t0, (1 << 17)
  csrc mstatus, t0

  csrr t1, mcause
  li t3, 9                    /* Environment call from S-mode. */
  bne t1, t3, unexpected_trap
  csrr t1, mepc
  la t3, supervisor_entry
  bne t1, t3, unexpected_trap

  and t2, t2, t0
  bnez t2, mprv_not_cleared
  PASS

mprv_not_cleared:
  FAIL(2)
unexpected_trap:
  FAIL(3)
