#include "test.h"

/*
 * Bug: Sdtrig mcontrol6 address-match triggers configured with match = 1
 * (NAPOT) fail to fire for accesses inside the configured naturally aligned
 * block, while exact-match (match = 0) triggers work.
 *
 * The core's NAPOT match function rejects any trigger address that has a
 * non-zero prefix above its trailing run of 1s (i.e. every real address),
 * so a NAPOT trigger never fires; the exact-match path is a plain equality
 * test and is unaffected.
 *
 * Repro strategy (all in M-mode, bare-metal, no MMU):
 *   Arm trigger 0 as an mcontrol6 EXECUTE-address trigger (select = 0,
 *   execute = 1, m = 1, action = breakpoint).
 *
 *   Phase 1: match = 0 (exact), tdata2 = `target`.  A fetch/decode of the
 *            instruction at `target` must raise a breakpoint exception on
 *            any spec-compliant core (and on this one, since exact match
 *            works).  The trap handler verifies this, re-arms the trigger
 *            with match = 1 (NAPOT) and tdata2 = `target` | 3 (the block
 *            containing `target`), and mret's back to `target`.
 *
 *   Phase 2: the re-fetch of `target` must raise a second breakpoint via
 *            the NAPOT trigger.  Spec-compliant core: it does -> PASS.
 *            Buggy core: the NAPOT match can never succeed, so `target`
 *            simply executes and the program reaches FAIL.
 */

  .section .text
  .globl test_main
  .align 2
test_main:
  csrci   mstatus, 8        /* clear MIE: no interrupts may interfere */
  li      s1, 0             /* s1: 0 = phase 1 (exact), 1 = phase 2 (NAPOT) */

  /* mcontrol6: type = 6, execute = 1, address match (select = 0), m = 1,
   * action = 0 (breakpoint), match = 0 (exact). */
  csrw    tselect, zero
  li      t0, 0x60000044    /* 0x6_0000_0044 */
  csrw    tdata1, t0
  la      t1, target
  csrw    tdata2, t1

  jal     zero, target      /* phase 1: must trap (exact match) */

  .align 2
target:
  addi    s0, zero, 1       /* executes only if a trigger failed to fire */
  j       did_not_fire

  .align 2
did_not_fire:
  FAIL(1)

  .align 2
  .globl trap_handler
trap_handler:
  csrr    t6, mcause
  csrr    t5, mepc
  li      t4, 3             /* BREAKPOINT */
  bne     t6, t4, not_bp
  la      t4, target
  bne     t5, t4, not_bp

  mv      t4, s1
  bnez    t4, napot_fired   /* phase 2: NAPOT trigger fired -> spec OK */

  /* Phase 1: exact-match trigger fired as expected.  Re-arm the same
   * trigger as NAPOT (match = 1): tdata2 = target | 3 selects the
   * naturally aligned 4-byte block containing `target`. */
  li      s1, 1
  li      t0, 0x600000c4    /* same as above but match = 1 (NAPOT) */
  csrw    tdata1, t0
  la      t1, target
  ori     t1, t1, 3
  csrw    tdata2, t1
  mret                      /* back to `target`; the NAPOT trigger must fire */

napot_fired:
  PASS

not_bp:
  FAIL(2)
