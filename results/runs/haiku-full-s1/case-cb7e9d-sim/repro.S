#include "test.h"
/* Sdtrig mcontrol6 execute trigger with match=1 (NAPOT).
 * tdata2 = blk | 7 selects a naturally aligned range that starts at blk and contains
 * the instruction `target` (blk+4). With the pmpaddr-style NAPOT encoding the range is
 * 16 bytes; with a size-1 reading it is 8 bytes. `target` is inside both, so the
 * trigger must fire there. Execution jumps straight to `target`, so it is the first
 * in-range instruction executed. */
  .option norvc
  .section .text
  .globl test_main
test_main:
  la t0, blk
  ori t0, t0, 7
  csrw tdata2, t0
  /* type=6 (mcontrol6), m=1, match=1 (NAPOT), execute=1, action=0 (breakpoint) */
  li t0, 0x60000000000000c4
  csrw tdata1, t0
  la t0, target
  jr t0

  .globl trap_handler
  .balign 4
trap_handler:
  csrr t0, mcause
  li t1, 3
  bne t0, t1, 1f
  csrr t0, mepc
  la t1, target
  bne t0, t1, 1f
  csrw tdata1, zero
  PASS
1: FAIL(2)

  .balign 16
blk:
  nop
target:
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  FAIL(1)
