#include "test.h"

  .section .text
  .globl test_main
test_main:
  # MRET with MPV=1 and MPP=S enters VS mode.  With both translation
  # controls in Bare mode, the guest executes from the same physical memory.
  li t0, (1 << 39)
  csrs mstatus, t0
  li t0, (1 << 11)
  csrs mstatus, t0
  la t0, guest
  csrw mepc, t0
  mret

guest:
  # custom3 opcode, funct3=2: the example CVXIF implementation rejects it,
  # so the core raises an illegal-instruction exception from VS mode.
  .word 0x0000207b
  FAIL(1)                         # Reaching here means no exception occurred.

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 2                        # Illegal instruction
  bne t0, t1, trap_fail

  csrr t0, mstatus
  srli t1, t0, 39                 # MPV must show the trap came from VS.
  andi t1, t1, 1
  beqz t1, trap_fail
  srli t1, t0, 38                 # GVA must be clear for illegal encoding.
  andi t1, t1, 1
  bnez t1, trap_fail

  PASS

trap_fail:
  FAIL(2)
