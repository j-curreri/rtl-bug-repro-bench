#include "test.h"

/* MRET must ignore MPV when MPP selects M-mode.  An ensuing trap
 * exposes the actual virtualization state in the saved mstatus.MPV.
 */
  .section .text
  .balign 4
  .globl test_main
test_main:
  /* Keep interrupts and data-privilege overrides out of the experiment. */
  csrw mie, zero
  csrw medeleg, zero
  li t0, ((1 << 3) | (1 << 7) | (1 << 17))
  csrc mstatus, t0

  la t0, returned_to_m
  csrw mepc, t0
  li t0, ((3 << 11) | (1 << 39))
  csrs mstatus, t0
  mret

returned_to_m:
expected_ecall:
  ecall
  /* ECALL must enter our handler, which is the only path to PASS. */
  FAIL(1)

  .balign 4
  .globl trap_handler
trap_handler:
  /* Reject any trap other than the ECALL at the intended MRET target. */
  csrr t0, mcause
  li t1, 11
  bne t0, t1, unexpected_trap
  csrr t0, mepc
  la t1, expected_ecall
  bne t0, t1, unexpected_trap

  csrr t0, mstatus
  li t1, (3 << 11)
  and t2, t0, t1
  bne t2, t1, unexpected_trap

  /* M-mode always has V=0, so trapping from it must save MPV=0.
   * Buggy MRET instead leaves V=1, which this trap saves as MPV=1.
   */
  li t1, (1 << 39)
  and t0, t0, t1
  bnez t0, bad_virtualization
  PASS

bad_virtualization:
  FAIL(2)
unexpected_trap:
  FAIL(3)
