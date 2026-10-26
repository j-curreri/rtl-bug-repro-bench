#include "test.h"

/* Sdtrig mcontrol6 with match=NAPOT (1) on a store address.
 * tdata2 = buf | 0xff encodes a 512-byte naturally aligned region (eight trailing ones,
 * then a zero bit at position 8, which is part of the don't-care range as in PMP NAPOT).
 * A store to buf + 0x100 lies inside that region, so the trigger must fire (breakpoint,
 * mcause 3). The buggy napot_match mask only ignores the trailing ones and compares bit 8,
 * so it does not match and the store goes through. */

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* select trigger 0 */
  li t0, 0
  csrw 0x7a0, t0            /* tselect */

  /* tdata2 = NAPOT region [buf, buf+0x200) */
  la t0, buf
  ori t0, t0, 0xff
  csrw 0x7a2, t0            /* tdata2 */

  /* tdata1: type=6 (mcontrol6), match=1 (NAPOT) at [10:7], m=1 at bit 6, store=1 at bit 1,
   * action=0 (raise breakpoint exception), size=0 (any) */
  li t0, 0x60000000000000c2
  csrw 0x7a1, t0            /* tdata1 */

  la t1, buf
  addi t1, t1, 0x100
  sd zero, 0(t1)            /* must trap on correct RTL */

  FAIL(1)                   /* reached only if the trigger did not fire */

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 3                  /* breakpoint */
  bne t0, t1, 1f
  PASS
1:
  FAIL(2)

  .data
  .balign 512
buf:
  .space 512
