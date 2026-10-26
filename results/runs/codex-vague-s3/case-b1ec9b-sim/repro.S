#include "test.h"

/* MRET to a privilege below M must clear mstatus.MPRV, even without H. */
  .section .text
  .balign 4
  .globl test_main
test_main:
  csrw mie, zero
  csrw medeleg, zero
  csrw satp, zero
  PMP_ALLOW_ALL

  /* Keep interrupts disabled and return to S-mode with MPRV initially set. */
  li t0, ((3 << 11) | (1 << 17) | (1 << 7) | (1 << 3))
  csrc mstatus, t0
  li t0, ((1 << 11) | (1 << 17))
  csrs mstatus, t0
  la t0, supervisor_entry
  csrw mepc, t0
  mret

supervisor_entry:
  /* Trap entry preserves MPRV, so the handler can inspect MRET's result. */
  ecall
  j unexpected

  .balign 4
  .globl trap_handler
trap_handler:
  /* Snapshot status and clear MPRV before any HTIF memory access. */
  li t0, (1 << 17)
  csrrc t1, mstatus, t0
  csrr t2, mcause
  li t3, 9                       /* Environment call from S-mode. */
  bne t2, t3, unexpected
  csrr t2, mepc
  la t3, supervisor_entry
  bne t2, t3, unexpected

  and t1, t1, t0
  bnez t1, mprv_not_cleared
  PASS

mprv_not_cleared:
  FAIL(1)

unexpected:
  li t0, (1 << 17)
  csrc mstatus, t0
  FAIL(2)
