#include "test.h"

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 11 /* Environment call from M-mode */
  bne t0, t1, 1f

  csrr t3, mepc
  la t4, ecall_insn
  bne t3, t4, 1f

  csrr t2, mtval
  /* According to RISC-V Privileged Specification (Section 3.1.20):
   * "For an environment call trap, mtval is set to zero."
   * On a compliant core: mtval == 0, ending with PASS.
   * On this buggy core: mtval == 0x73 (instruction opcode), ending with FAIL.
   */
  bnez t2, 1f
  PASS

1:
  FAIL(1)

  .globl test_main
test_main:
ecall_insn:
  ecall
  FAIL(2)
