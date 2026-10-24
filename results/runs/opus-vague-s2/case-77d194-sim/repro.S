/* hgatp write with an unsupported MODE.
 *
 * Privileged spec (H extension, hgatp): "A write to hgatp with an unsupported
 * MODE value is not ignored as it is for satp. Instead, the fields of hgatp are
 * WARL in the normal way, when so indicated."
 *
 * So writing MODE=9 (Sv48x4, unsupported on this Sv39 core) together with a
 * legal PPN must still update the PPN field; only MODE may be legalized. The
 * buggy core drops the whole write like satp does, so the old PPN remains.
 * MODE and VMID are not checked, so any legal MODE result is accepted.
 */
#include "test.h"

#define HGATP_PPN_MASK 0x00000fffffffffff

.text
.globl test_main
test_main:
  /* Start from a known, supported value: Bare, PPN 0x80004. */
  li t0, 0x80004
  csrw hgatp, t0
  csrr t1, hgatp
  li t2, HGATP_PPN_MASK
  and t1, t1, t2
  li t3, 0x80004
  bne t1, t3, fail_setup

  /* MODE=9 (Sv48x4, unsupported), PPN 0x80008 (16 KiB aligned, legal). */
  li t0, (9 << 60) | 0x80008
  csrw hgatp, t0
  csrr t1, hgatp
  li t2, HGATP_PPN_MASK
  and t1, t1, t2
  li t3, 0x80008
  bne t1, t3, fail_ignored

  /* Restore Bare mode. */
  csrw hgatp, zero
  PASS

fail_setup:
  FAIL(1)
fail_ignored:
  FAIL(2)
