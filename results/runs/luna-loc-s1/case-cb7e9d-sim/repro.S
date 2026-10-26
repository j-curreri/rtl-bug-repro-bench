#include "test.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  /* Type 6, NAPOT match, M-mode execute address, breakpoint action. */
  csrw tselect, zero
  la t0, napot_probe
  ori t0, t0, 1                 /* encode a small NAPOT region containing probe */
  csrw tdata2, t0
  li t0, 0x60000000000000c4     /* type=6, match=NAPOT, m=1, execute=1 */
  csrw tdata1, t0
  nop

napot_probe:
  .option push
  .option norvc
  nop
  .option pop
  FAIL(1)                       /* a conforming core traps before reaching here */

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 3                      /* breakpoint exception */
  bne t0, t1, trap_fail
  csrr t0, mepc
  la t1, napot_probe
  bne t0, t1, trap_fail
  PASS
trap_fail:
  FAIL(2)
