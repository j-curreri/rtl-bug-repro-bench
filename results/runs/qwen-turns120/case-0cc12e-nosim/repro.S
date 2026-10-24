/* Reproducer for the CVA6 mtval bug.
 *
 * Per the RISC-V privileged spec, when a trap is taken:
 *   - ECALL from M-mode (cause 11):  mtval must be 0
 *   - BREAKPOINT      (cause 3):    mtval must hold the virtual address of
 *                                   the instruction that raised the exception
 *                                   (i.e. the PC of the ebreak, == mepc)
 *
 * This core instead leaves mtval holding the raw instruction encoding for
 * both exceptions (the zero-tval path in csr_regfile is gated on
 * ariane_pkg::ZERO_TVAL, which is 0 without SPIKE_TANDEM, and the decoder
 * seeds ex.tval with the instruction bits for every instruction), so:
 *   - after ecall:  mtval == 0x00000073 != 0   -> FAIL(1)
 *   - after ebreak: mtval == 0x00100073 != PC  -> FAIL(2)
 *
 * A spec-conformant core passes both checks and reaches PASS.
 */
#include "test.h"

  .section .text
  .globl test_main
  .align 2
test_main:
  /* Keep the run deterministic: no M-mode interrupts can preempt us. */
  csrci mstatus, 3

  /* Test 1: M-mode ECALL must leave mtval == 0.
   * The trap handler checks and advances mepc past the ecall. */
  ecall

  /* Test 2: M-mode BREAKPOINT must leave mtval == PC of the ebreak.
   * The trap handler checks and advances mepc past the ebreak.
   * Force the 32-bit encoding so the handler's mepc += 4 is always exact. */
  .option push
  .option norvc
  ebreak
  .option pop

  /* Both mtval values matched the privileged spec. */
  PASS

/* Strong override of the weak default trap_handler in crt.S. */
  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  csrr t1, mtval
  csrr t2, mepc

  li t3, 11                    /* ENV_CALL_MMODE */
  beq t0, t3, handle_ecall

  li t3, 3                    /* BREAKPOINT */
  bne t0, t3, unhandled_trap
  /* Spec: mtval = virtual address of the trapping instruction, which is
   * the PC of the ebreak and therefore equal to mepc. */
  bne t1, t2, fail_bp
  addi t2, t2, 4
  csrw mepc, t2
  mret

handle_ecall:
  /* Spec: mtval = 0 for environment calls. */
  bnez t1, fail_ecall
  addi t2, t2, 4
  csrw mepc, t2
  mret

fail_ecall:
  FAIL(1)
fail_bp:
  FAIL(2)
unhandled_trap:
  FAIL(127)
