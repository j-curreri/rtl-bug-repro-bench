#include "test.h"

/* Sdtrig mcontrol6 execute trigger, NAPOT match, on an address whose upper bits are set.
 * A correct core fires the breakpoint before `target` runs; the buggy core's napot_match
 * rejects the (valid) NAPOT encoding, so `target` runs and we FAIL. */

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* tselect = 0 */
  li t0, 0
  csrw 0x7a0, t0

  /* tdata2 = NAPOT encoding of a naturally aligned region starting at `target`:
   * target's low 6 bits cleared, then trailing ones set (so `target` itself is covered). */
  la t0, target
  andi t0, t0, -64
  ori t0, t0, 0x1f
  csrw 0x7a2, t0

  /* tdata1 (RV64): type=6 (mcontrol6) in [63:60], m=1, execute=1, match=1 (NAPOT), action=0 (breakpoint) */
  li t0, (6 << 60) | (1 << 6) | (1 << 2) | (1 << 7)
  csrw 0x7a1, t0
  fence.i

  jal ra, target

  /* Trigger did not fire on target. */
  FAIL(1)

target:
  nop
  nop
  ret

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 3                /* breakpoint: the trigger fired as the spec requires */
  bne t0, t1, 1f
  PASS
1:
  FAIL(2)
