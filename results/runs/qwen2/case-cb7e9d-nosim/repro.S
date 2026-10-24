/* Repro: Sdtrig mcontrol6 store-address trigger with match=NAPOT fails to fire
 * for accesses inside the configured naturally aligned range.
 *
 * Trigger 0 is programmed as an mcontrol6 (tdata1 type = 6):
 *   - m = 1          (fire in M-mode)
 *   - store = 1, load = execute = 0
 *   - select = 0     (match on address, not data)
 *   - match  = 1     (NAPOT)
 *   - action = 0     (breakpoint)
 * and tdata2 holds the canonical NAPOT encoding of the 4 KiB range
 * [page_base(flag), page_base(flag)+0xFFF] (lowest set bit at position 11).
 *
 * A store to `flag`, which lies inside that range, must raise a breakpoint
 * exception (mcause = 3) on a spec-conformant core.  The handler records the
 * trap in `trap_seen`, disables the trigger and mrets.  Afterwards
 * trap_seen != 0  ->  PASS,  otherwise -> FAIL(1).
 *
 * On the buggy core, napot_match64() rejects this tdata2
 * (tdata2 & (tdata2 + 1) != 0 is treated as "not a valid NAPOT"), so the
 * trigger never fires, trap_seen stays 0 and the program FAILs.
 */
#include "test.h"

  .section .text
  .globl test_main
  .align 2
test_main:
  PMP_ALLOW_ALL

  la t2, flag
  la t3, trap_seen
  li t0, 0
  sd t0, 0(t2)                /* flag = 0        (before the trigger is armed) */
  sd t0, 0(t3)                /* trap_seen = 0   (before the trigger is armed) */

  /* Arm the mcontrol6 NAPOT store-address trigger on trigger 0.
   * tdata1 = type mcontrol6(6)<<60 | match NAPOT(1)<<7 | m(1)<<6 | store(1)<<1
   *        = 0x60000000000000C2
   * (select = 0 -> address match, action = 0 -> breakpoint) */
  li t0, 0
  csrw tselect, t0
  li t0, 0x60000000000000C2
  csrw tdata1, t0

  /* tdata2 = page base of `flag` with bit 11 set: canonical NAPOT encoding
   * of the 4 KiB naturally aligned range containing `flag`. */
  srli t0, t2, 12
  slli t0, t0, 12
  li t1, 0x800
  or t0, t0, t1
  csrw tdata2, t0

  /* This store is inside the configured NAPOT range: on a correct core it
   * must fire the trigger and raise a breakpoint. */
  li t1, 42
  sd t1, 0(t2)

  la t0, trap_seen
  ld t0, 0(t0)
  beqz t0, no_trap
  PASS

no_trap:
  FAIL(1)

/* M-mode trap handler; mtvec is set to trap_handler by _start. */
  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 3                    /* m-breakpoint */
  bne t0, t1, bad_cause
  /* Disable the trigger (type 15 = off) so the mret below cannot re-trigger. */
  li t0, 0xF000000000000000
  csrw tdata1, t0
  la t0, trap_seen
  li t1, 1
  sd t1, 0(t0)
  mret

bad_cause:
  FAIL(130)

  .section .data
  .align 3
  .globl flag
flag: .dword 0
  .globl trap_seen
trap_seen: .dword 0
