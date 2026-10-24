#include "test.h"

/*
 * Bug: after a synchronous "environment call" (ecall) or "breakpoint"
 * (ebreak), the RISC-V privileged spec requires mtval to be 0.  This core
 * instead leaves the faulting instruction's own bits in mtval for those
 * causes (the zero-tval handling is disabled), so after an ecall mtval
 * holds the ecall opcode rather than 0.
 *
 * The test raises an M-mode ecall and, in the trap handler, verifies that
 * mtval == 0.  A spec-compliant core has mtval == 0 and the test PASSes.
 * This buggy core has mtval != 0 and the test FAILs.
 *
 * We finish from inside the handler rather than mret-ing: on this core,
 * mret after an ecall does not resume at the following instruction, so the
 * handler terminates the test directly via the PASS/FAIL macros.
 */

  .section .text
  .globl test_main
test_main:
    la      t0, trap_handler
    csrw    mtvec, t0
    ecall                     /* M-mode environment call; mcause = 11 */

  .align 2
  .globl trap_handler
trap_handler:
    csrr    t0, mcause
    li      t1, 11            /* ENV_CALL_MMODE */
    bne     t0, t1, fail_cause
    csrr    t0, mtval
    bnez    t0, fail_mtval    /* non-zero mtval after ecall => the bug */
    PASS                      /* mtval == 0: spec-compliant */

fail_mtval:
    FAIL(1)                   /* mtval was non-zero after ecall */
fail_cause:
    FAIL(2)                   /* not the expected ecall cause */
