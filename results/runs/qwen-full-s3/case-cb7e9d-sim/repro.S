#include "test.h"

/*
 * Bug: Sdtrig mcontrol6 address triggers with match=1 (NAPOT) fail to fire for
 * accesses inside the configured naturally aligned power-of-two range, while
 * exact-match (match=0) triggers work.
 *
 * Reproducer:
 *   - Arm trigger 0 in M-mode as a LOAD-address trigger, match=NAPOT,
 *     action=breakpoint, with tdata2 = B = 0x8000_8800 (lowest set bit is bit 7).
 *     Per the Sdtrig spec, addresses with bit 7 set must match, i.e. the
 *     naturally aligned range [0x8000_8780, 0x8000_887F].
 *   - Load from T = 0x8000_8840 (bit 7 set; inside the range under every
 *     sane NAPOT interpretation).
 *   - Correct core: the load raises a breakpoint exception (mcause = 3) at
 *     target_load. Our trap handler records that, disables the trigger and
 *     resumes; the load re-executes cleanly and we end with PASS.
 *   - Buggy core: the NAPOT match is computed as always false for a natural
 *     base (0x8000_8800 & 0x8000_8801 != 0), so no trigger, no trap:
 *     the program reaches the end check and FAILs.
 *
 * FAIL codes: 2 = trigger did not fire; 3 = target memory round-trip broken;
 *             127 = unexpected trap.
 */

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* sentinel in the target memory location (before the trigger is armed) */
  li   s1, 0x80008840                 /* target address T = B + 0x40 */
  li   t0, 0x5A5A5A5A5A5A5A5A         /* sentinel */
  sd   t0, 0(s1)

  /* trigger-fired flag starts clear */
  la   t0, trig_flag
  li   t1, 0
  sd   t1, 0(t0)

  /* Arm trigger 0: mcontrol6, M-mode only, load address, NAPOT, breakpoint.
   * tdata1 = [63:60]=6 (mcontrol6), [10:7]=1 (NAPOT), [6]=m, [0]=load */
  li   t0, 0
  csrw tselect, t0
  li   t0, 0x60000000000000C1
  csrw tdata1, t0
  li   t0, 0x80008800                 /* NAPOT base B (lowest set bit = bit 7) */
  csrw tdata2, t0

  /* the access that must fire the trigger */
target_load:
  lw   a1, 0(s1)

  /* disarm the trigger (type 15 = disabled) so the re-executed load
   * (after mret) cannot fire it a second time */
  li   t0, 0xF000000000000000
  csrw tdata1, t0

  /* sanity: the load must have returned the sentinel */
  li   t0, 0x5A5A5A5A5A5A5A5A
  bne  a1, t0, fail_rt

  /* did the NAPOT trigger fire? */
  la   t0, trig_flag
  ld   a0, 0(t0)
  beqz a0, fail_no_trig
  PASS

fail_rt:
  FAIL(3)
fail_no_trig:
  FAIL(2)

/* Our own trap handler: a breakpoint (mcause = 3) at target_load means the
 * NAPOT load trigger fired. Record it, disable the trigger, resume. */
  .align 2
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  csrr x18, mepc
  la   t5, target_load
  li   t4, 3                          /* mcause = breakpoint */
  bne  t6, t4, not_mine
  bne  x18, t5, not_mine

  la   t5, trig_flag
  li   t4, 1
  sd   t4, 0(t5)
  li   t4, 0xF000000000000000         /* type 15: disabled */
  csrw tselect, zero
  csrw tdata1, t4
  mret
not_mine:
  li   a0, 255                        /* FAIL(127): unexpected trap */
  j    _halt

  .data
trig_flag:
  .dword 0
