#include "test.h"

/* The RV32 encoding of rev8 (imm 0x698) is reserved on RV64 and must raise an
 * illegal-instruction trap (mcause 2). The buggy decoder executes it as rev8. */

  .text
  .globl test_main
test_main:
  la t0, trap_idx
  sd zero, 0(t0)
  .insn i 0x13, 5, x7, x0, 0x698
  la t0, trap_idx
  ld t1, 0(t0)
  li t2, 1
  bne t1, t2, 1f
  la t0, trap_log
  ld t1, 0(t0)
  li t2, 2
  bne t1, t2, 1f
  PASS
1:
  FAIL(1)

  .data
  .align 3
trap_idx: .dword 0
trap_log: .dword 0

  .text
  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  la t1, trap_log
  sd t0, 0(t1)
  la t1, trap_idx
  ld t2, 0(t1)
  addi t2, t2, 1
  sd t2, 0(t1)
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret
