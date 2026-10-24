#include "test.h"

/*
 * Reproducer for an mtval bug on synchronous environment calls and breakpoints.
 *
 * RISC-V Privileged spec requirement:
 *   - After an M-mode ECALL, mtval must contain 0.
 *   - After an EBREAK, mtval must contain the address of the breakpoint
 *     instruction (mepc) or 0 -- never the raw instruction encoding.
 *
 * This core, however, stores the *raw instruction encoding* in mtval for those
 * synchronous exceptions:
 *   - decoder.sv sets ex.tval to the raw instruction bits for decode-stage
 *     exceptions, and
 *   - csr_regfile.sv only clears mtval to 0 for these causes when the
 *     SPIKE_TANDEM-only ZERO_TVAL flag is set.  In a normal build that flag is
 *     0, so mtval keeps the encoding.
 *
 * Result on this (buggy) core:
 *   M-mode ECALL  -> mtval = 0x00000073  (ECALL is always 32-bit)
 *   M-mode EBREAK -> mtval = the EBREAK encoding (0x00100073 expanded, or
 *                    0x00009002 if the assembler emitted the c.ebreak form)
 *
 * Strategy: raise an M-mode ECALL first (always 32-bit) and, from the handler,
 * verify mtval == 0 then resume with mret (mepc + 4).  Then raise an M-mode
 * EBREAK and, from the handler, verify mtval is a valid value (0 or mepc) and
 * end the test directly (no mret, so the possibly-compressed EBREAK size is
 * irrelevant).
 *
 * A spec-compliant core passes both checks and ends with PASS.  On the buggy
 * core the first check fails and the program reports FAIL(n).
 */

  .section .text
  .globl test_main
test_main:
  la t0, trap_handler
  csrw mtvec, t0
  /* M-mode environment call (32-bit) -> synchronous trap, mcause = 11 */
  ecall
  /* Returned from the handler; now raise a breakpoint -> mcause = 3 */
  ebreak
  /* Reached only if both mtval values were spec-compliant */
  PASS

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  csrr t1, mtval
  csrr t2, mepc

  /* Dispatch on the exception cause */
  li t3, 11
  beq t0, t3, handle_ecall
  li t3, 3
  beq t0, t3, handle_ebreak
  FAIL(1)      /* some other trap than the two we intended */

handle_ecall:
  /* Spec: mtval must be 0 after an environment call.
   * Buggy core stores the ECALL encoding 0x00000073 here. */
  bne t1, x0, ecall_bad
  /* ECALL is always a 32-bit instruction; resume at the next one. */
  addi t2, t2, 4
  csrw mepc, t2
  mret

handle_ebreak:
  /* Spec: mtval is the breakpoint address (mepc) or 0, never the raw
   * encoding.  Buggy core stores the EBREAK encoding here. */
  beq t1, x0, both_ok
  beq t1, t2, both_ok
  j ebreak_bad

ecall_bad:
  FAIL(2)

ebreak_bad:
  FAIL(3)

both_ok:
  PASS
