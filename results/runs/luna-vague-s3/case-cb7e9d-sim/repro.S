#include "test.h"

  .section .text
  .option norvc
  .align 2
  .globl test_main
test_main:
  li s0, 0
  csrw tselect, zero
  la t0, watched_word
  ori t0, t0, 7             /* NAPOT encoding for an 8-byte region */
  csrw tdata2, t0
  li t0, 0x60000000000000c2 /* type=6, m=1, store=1, match=NAPOT */
  csrw tdata1, t0

  la t0, watched_word
  li t1, 0x1234
store_instruction:
  sw t1, 4(t0)               /* upper word of the 8-byte NAPOT region */
  beqz s0, trigger_missed
  PASS
trigger_missed:
  FAIL(1)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 3
  bne t0, t1, unexpected_trap
  csrr t0, mepc
  la t1, store_instruction
  bne t0, t1, unexpected_trap
  li s0, 1
  addi t0, t0, 4
  csrw mepc, t0
  mret
unexpected_trap:
  FAIL(2)

  .section .data
  .align 3
watched_word:
  .dword 0
