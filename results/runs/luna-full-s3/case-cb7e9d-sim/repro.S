#include "test.h"

  .section .text
  .option norvc
  .align 2
  .globl test_main
test_main:
  /* Match any execution address in the naturally aligned 8-byte NAPOT range. */
  la t0, probe
  ori t0, t0, 7
  csrw tdata2, t0

  /* mcontrol6: type=6, match=NAPOT, M privilege, execute, breakpoint action. */
  li t0, 0x600000c4
  csrw tdata1, t0
  fence.i

  li s0, 0
.balign 8
probe:
  addi t1, t1, 1
  addi t1, t1, 1
after_probe:
  beqz s0, failed
  PASS
failed:
  FAIL(1)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 3                    /* breakpoint exception */
  bne t0, t1, unexpected_trap
  csrr t0, mepc
  la t1, probe
  bne t0, t1, unexpected_trap

  /* Record the expected trap, disarm the trigger, and resume after probe. */
  li s0, 1
  csrw tdata1, zero
  la t0, after_probe
  csrw mepc, t0
  mret
unexpected_trap:
  FAIL(127)
