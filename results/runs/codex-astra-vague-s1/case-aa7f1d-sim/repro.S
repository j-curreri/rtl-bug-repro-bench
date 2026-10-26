#include "test.h"

/* MRET with MPP=M must set V=0, irrespective of the saved MPV bit.
 * An immediately following M-mode ECALL exposes V in the trap's saved MPV.
 * No address translation, guest execution, or external interrupts are needed.
 */
  .section .text
  .balign 4
  .globl test_main
test_main:
  csrw mie, zero
  csrw medeleg, zero
  csrw mideleg, zero
  la t0, trap_handler
  csrw mtvec, t0

  la t0, returned_to_m
  csrw mepc, t0
  /* MPP=3, MPV=1; MIE=MPIE=MPRV=0. */
  li t0, ((1 << 39) | (3 << 11))
  csrw mstatus, t0
  mret

  .balign 4
returned_to_m:
  ecall
  FAIL(1)

  .balign 4
  .globl trap_handler
trap_handler:
  /* Only the deliberate ECALL from M-mode is expected. */
  csrr t0, mcause
  li t1, 11
  bne t0, t1, unexpected_trap
  csrr t0, mepc
  la t1, returned_to_m
  bne t0, t1, unexpected_trap

  csrr t2, mstatus
  li t1, (3 << 11)
  and t0, t2, t1
  bne t0, t1, wrong_privilege
  li t1, (1 << 39)
  and t0, t2, t1
  bnez t0, wrong_virtualization
  PASS

unexpected_trap:
  FAIL(2)
wrong_privilege:
  FAIL(3)
wrong_virtualization:
  FAIL(4)
