#include "test.h"

  .section .text
  .align 2
  .option norvc
  .globl test_main
test_main:
  la t0, trigger_seen
  sd zero, 0(t0)

  /* Select trigger 0 and configure an M-mode execute NAPOT match. */
  csrw tselect, zero
  la t0, watched_instruction
  ori t0, t0, 3                 /* 8-byte NAPOT region containing the target */
  csrw tdata2, t0
  li t0, (6 << 60) | (1 << 10) | (1 << 6) | (1 << 2)
  csrw tdata1, t0               /* mcontrol6, NAPOT, M, execute, breakpoint */

  la t0, watched_instruction
  jr t0
  .align 2
watched_instruction:
  addi s0, s0, 1
after_watched_instruction:
  la t0, trigger_seen
  ld t0, 0(t0)
  beqz t0, fail_no_trigger
  PASS

fail_no_trigger:
  FAIL(1)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 3                      /* breakpoint exception from the trigger */
  bne t0, t1, unexpected_trap

  la t0, trigger_seen
  li t1, 1
  sd t1, 0(t0)
  csrw tdata1, zero              /* disable before returning to the target */
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret

unexpected_trap:
  FAIL(127)

  .section .bss
  .align 3
trigger_seen:
  .dword 0
