/*
 * Reproducer for: "When a machine-mode interrupt is taken, mtval does not
 * always read as zero in the trap handler."
 *
 * The RISC-V privileged spec (and this core's stated contract) require that
 * mtval be written with 0 when a machine-mode interrupt is taken.
 *
 * Root cause on this buggy core (core/csr_regfile.sv):
 *     mtval_d = (ZERO_TVAL && (... || ex_i.cause[XLEN-1])) ? '0 : ex_i.tval;
 * In a normal build ariane_pkg::ZERO_TVAL == 0, so for an interrupt this
 * reduces to  mtval_d = ex_i.tval.  The decoder (core/decoder.sv) stores the
 * *instruction word* of every normally-decoded instruction into ex.tval, so
 * ex_i.tval is the non-zero word of the interrupted instruction.  Hence the
 * handler observes a non-zero mtval instead of 0.
 *
 * This program raises the machine software interrupt (CLINT MSIP), takes it,
 * and verifies that mtval == 0 in the M-mode trap handler.
 *   - A spec-correct core gives mtval == 0  -> PASS.
 *   - This buggy core gives mtval == <instr word> != 0 -> FAIL.
 */
#include "test.h"

  .globl test_main
  .globl trap_handler

/* CLINT machine software interrupt pending register, hart 0. */
#define MSIP0 0x02000000

test_main:
  la sp, _stack_top

  la t0, trap_handler
  csrw mtvec, t0

  /* Enable only the machine software interrupt. */
  li t0, 1 << 3
  csrw mie, t0

  /* Raise the machine software interrupt. */
  li t0, MSIP0
  li t1, 1
  sd t1, 0(t0)

  /* Enable M-mode interrupts: the pending MSIP is taken at the next commit. */
  li t0, 1 << 3
  csrs mstatus, t0

  /* Block until the interrupt is serviced. */
  wfi

  /* If control reaches here the interrupt was never taken. */
  FAIL(1)

  .align 2
trap_handler:
  csrr t0, mcause
  csrr t1, mtval

  /* This must be the machine software interrupt we raised:
   * mcause = (1 << 63) | 3 = 0x8000000000000003. */
  li t2, 0x8000000000000003
  bne t0, t2, 2f

  /* The privileged spec requires mtval == 0 for a machine-mode interrupt. */
  bnez t1, 3f
  PASS

2:  /* A different trap was taken than expected. */
  FAIL(2)

3:  /* mtval is non-zero after a machine-mode interrupt: the bug. */
  FAIL(3)
