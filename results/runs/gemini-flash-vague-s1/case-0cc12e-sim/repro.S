#include "test.h"

  .section .text
  .globl test_main
test_main:
  /* Write a non-zero pattern to mtval first to verify it gets updated. */
  li t0, 0x1234
  csrw mtval, t0

ecall_insn:
  ecall
  FAIL(1)

  .align 2
  .globl trap_handler
trap_handler:
  /* Verify exception cause is environment call from M-mode (cause 11). */
  csrr t0, mcause
  li t1, 11
  bne t0, t1, 1f

  /* Verify mepc points to the faulting ecall instruction. */
  csrr t0, mepc
  la t1, ecall_insn
  bne t0, t1, 2f

  /* Per RISC-V Privileged Specification:
   * "For an environment call exception, mtval is set to zero."
   * On the buggy core, mtval is erroneously written with the instruction word (0x73).
   */
  csrr t0, mtval
  bnez t0, 3f

  PASS

1:
  FAIL(2) // unexpected mcause
2:
  FAIL(3) // unexpected mepc
3:
  FAIL(4) // mtval != 0 (spec requires 0)
