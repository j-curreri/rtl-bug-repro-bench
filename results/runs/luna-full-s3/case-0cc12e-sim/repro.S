#include "test.h"

  .section .text
  .option norvc
  .globl test_main
test_main:
  ecall
  .globl breakpoint_insn
breakpoint_insn:
  ebreak
  PASS

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 11                    # Environment call from M-mode
  beq t0, t1, check_ecall
  li t1, 3                     # Breakpoint
  beq t0, t1, check_breakpoint
  FAIL(1)

check_ecall:
  csrr t0, mtval
  bnez t0, fail_ecall_tval
  csrr t0, mepc
  la t1, test_main
  bne t0, t1, FAIL_ECALL_PC
  addi t0, t0, 4
  csrw mepc, t0
  mret

check_breakpoint:
  csrr t0, mtval
  la t1, breakpoint_insn
  bne t0, t1, FAIL_BREAK_TVAL
  csrr t0, mepc
  bne t0, t1, FAIL_BREAK_PC
  addi t0, t0, 4
  csrw mepc, t0
  mret

fail_ecall_tval:
  FAIL(2)
FAIL_ECALL_PC:
  FAIL(3)
FAIL_BREAK_TVAL:
  FAIL(4)
FAIL_BREAK_PC:
  FAIL(5)

