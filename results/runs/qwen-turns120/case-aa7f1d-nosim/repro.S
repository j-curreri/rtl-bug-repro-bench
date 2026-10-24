/* repro.S -- reproducer for the MRET / mstatus.MPV virtualization-state bug.
 *
 * The bug: on a core with the H extension, executing MRET while mstatus.MPP
 * selects M-mode and mstatus.MPV is set leaves the hart in an inconsistent
 * virtualization state (V = 1 even though the hart returned to M-mode).
 * Per the RISC-V spec, MPV is ignored when returning to M-mode, so the hart
 * must end up in M-mode with V = 0.
 *
 * How this detects it: when the virtualization bit V is 1, accesses to the
 * HS-mode page-table register are redirected, so a read of `satp` actually
 * returns `vsatp`.  We therefore store two distinct values in the host table
 * base `satp` and the guest table base `vsatp`, then perform an MRET into
 * M-mode with MPV set.  After the return we read `satp`:
 *   - a correct core returned to M-mode with V=0, so the read yields the host
 *     value  -> PASS
 *   - the buggy core is still V=1, so the read is redirected to vsatp and
 *     yields the guest value -> FAIL
 */
#include "test.h"
#include "hyp.h"

  /* Distinct host vs. guest Sv39 table bases.  M-mode is never translated, so
   * these never cause a fault even though the PTEs they point at do not exist. */
  .equ HOST_PTN,  0x8000000000001000   /* satp:  mode=Sv39 (8), host PPN */
  .equ GUEST_PTN, 0x8000000000002000   /* vsatp: mode=Sv39 (8), guest PPN */

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Publish different values in the host and guest table bases. */
  li t0, HOST_PTN
  csrw satp, t0
  li t0, GUEST_PTN
  csrw vsatp, t0

  /* mret into M-mode (MPP=2) with MPV=1.  The spec requires the hart to come
   * back in M-mode with V=0 because MPV is ignored for an M-mode return. */
  li t0, MSTATUS_MPV
  csrs mstatus, t0
  ENTER_MODE(2, check)

check:
  /* Back in M-mode.  Read `satp`: a correct core (V=0) gives the host value;
   * a buggy core (V=1) has redirected the read to `vsatp` and gives the guest. */
  csrr t0, satp
  li t1, GUEST_PTN
  bne t0, t1, ok
  FAIL(1)

ok:
  PASS
