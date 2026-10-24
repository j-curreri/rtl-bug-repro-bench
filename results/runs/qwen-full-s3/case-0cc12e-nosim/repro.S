/* Bug reproducer: mtval after some synchronous exceptions does not match the
 * privileged spec (bug report: "Environment calls and breakpoints are
 * affected").
 *
 * RISC-V Privileged spec requirement for these synchronous exceptions:
 *   - ECALL from any mode : mtval = 0
 *   - BREAKPOINT (ebreak) : mtval = virtual address of the faulting
 *                           instruction (which equals mepc here)
 *
 * On a spec-conformant core this program ends with PASS. On the buggy core
 * the decoder stores the raw instruction encoding into the exception tval,
 * so after the M-mode ecall mtval holds 0x00000073 instead of 0 and the
 * program ends with FAIL(1) before the second check.
 *
 * Everything runs in M-mode (harness start mode), so both exceptions trap to
 * the M-mode handler below; mcause values used for dispatch:
 *   ecall from M-mode = 11, breakpoint = 3.
 */
#include "test.h"

  .globl test_main
test_main:
  /* check 1: ecall from M-mode -> mcause 11, mtval must be 0 */
  ecall

  /* check 2: ebreak in M-mode -> mcause 3, mtval must be this instruction's PC
   * (force the 32-bit encoding so mepc advance is unambiguously 4) */
  .option norvc
  ebreak
  .option rvc

  /* reached only if the trap handler validated both mtval values */
  PASS

/* M-mode trap handler: validate mtval for the expected cause, advance mepc
 * past the 32-bit faulting instruction, mret. */
  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  csrr t1, mtval
  csrr t2, mepc
  li   t5, 11
  beq  t0, t5, h_ecall
  li   t5, 3
  beq  t0, t5, h_ebreak
  j    fail_other
h_ecall:
  beq  t1, zero, ok_ecall
  j    fail_ecall
ok_ecall:
  addi t2, t2, 4
  mret
h_ebreak:
  beq  t1, t2, ok_ebreak
  j    fail_ebreak
ok_ebreak:
  addi t2, t2, 4
  mret
fail_ecall:
  FAIL(1)
fail_ebreak:
  FAIL(2)
fail_other:
  FAIL(3)
