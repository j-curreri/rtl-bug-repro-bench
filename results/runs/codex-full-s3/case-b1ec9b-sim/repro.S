#include "test.h"

/* MRET to S-mode must clear mstatus.MPRV (bit 17), including without H.
 * ECALL brings us back to M-mode without modifying MPRV, so the handler
 * can inspect the result.  No data accesses occur with MPRV set, and the
 * handler clears it before using the harness's memory-based exit path.
 */
  .section .text
  .balign 4
  .globl test_main
test_main:
  csrw mie, zero
  csrw medeleg, zero
  csrw satp, zero
  sfence.vma
  PMP_ALLOW_ALL

  /* Disable interrupts, clear MPP/MPRV, and select S-mode for MRET. */
  li t0, ((1 << 17) | (3 << 11) | (1 << 3))
  csrc mstatus, t0
  li t0, ((1 << 17) | (1 << 11))
  csrs mstatus, t0

  /* Confirm that the test really starts with MPRV set. */
  csrr t1, mstatus
  li t0, (1 << 17)
  and t1, t1, t0
  beqz t1, setup_failed

  la t0, supervisor_entry
  csrw mepc, t0
  mret

supervisor_entry:
  ecall
  j unexpected_trap

  .balign 4
  .globl trap_handler
trap_handler:
  /* Save the observed bit before clearing it for PASS/FAIL stores. */
  csrr t1, mstatus
  li t0, (1 << 17)
  csrc mstatus, t0
  and t1, t1, t0

  csrr t2, mcause
  li t3, 9                      /* Environment call from S-mode. */
  bne t2, t3, unexpected_trap
  csrr t2, mepc
  la t3, supervisor_entry
  bne t2, t3, unexpected_trap

  bnez t1, mprv_retained
  PASS

mprv_retained:
  FAIL(1)

setup_failed:
  li t0, (1 << 17)
  csrc mstatus, t0
  FAIL(2)

unexpected_trap:
  li t0, (1 << 17)
  csrc mstatus, t0
  FAIL(3)
