#include "test.h"

/* MRET with MPP=M must ignore MPV and keep virtualization disabled.
 * A subsequent M-mode ECALL exposes V in the trap's saved mstatus.MPV.
 * No address translation or lower-privilege execution is required.
 */
  .section .text
  .balign 4
  .globl test_main
test_main:
  csrw mie, zero
  csrw medeleg, zero
  csrw mideleg, zero

  la t0, after_mret
  csrw mepc, t0

  /* Preserve unrelated status fields; disable interrupts and MPRV. */
  csrr t0, mstatus
  li t1, ((1 << 17) | (3 << 11) | (1 << 7) | (1 << 3))
  not t1, t1
  and t0, t0, t1
  li t1, ((1 << 39) | (3 << 11))
  or t0, t0, t1
  csrw mstatus, t0
  mret

after_mret:
  /* Correct: M-mode, V=0, despite the MPV=1 supplied to MRET. */
  ecall
  FAIL(1)

  .balign 4
  .globl trap_handler
trap_handler:
  /* Only the ECALL immediately after MRET is an expected trap. */
  csrr t0, mcause
  li t1, 11
  bne t0, t1, unexpected_trap
  csrr t0, mepc
  la t1, after_mret
  bne t0, t1, unexpected_trap

  csrr t0, mstatus
  li t1, (1 << 39)
  and t1, t0, t1
  bnez t1, bad_virtualization

  /* The trap must also report that the ECALL came from M-mode. */
  li t1, (3 << 11)
  and t0, t0, t1
  bne t0, t1, unexpected_trap
  PASS

bad_virtualization:
  FAIL(2)
unexpected_trap:
  FAIL(3)
