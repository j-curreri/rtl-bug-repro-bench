/* An mcontrol6 NAPOT execute trigger (match=1) covering an 8-byte region must fire when
 * U-mode executes an instruction inside it. */
#include "test.h"
  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  csrw tselect, zero
  la t0, target
  ori t0, t0, 3                /* NAPOT encoding of an 8-byte region */
  csrw tdata2, t0
  /* type=6, action=0 (breakpoint), match=1 (NAPOT), u=1, execute=1 */
  li t0, (6 << 60) | (1 << 7) | (1 << 3) | (1 << 2)
  csrw tdata1, t0
  ENTER_MODE(0, in_umode)
in_umode:
  nop
  .align 3
target:
  nop
  nop                          /* second instruction inside the region */
  ecall

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 3                     /* breakpoint */
  bne t0, t1, 1f
  PASS
1: FAIL(1)
