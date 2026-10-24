/* Repro for the PMP TOR-boundary bug (PMP grain G=1, i.e. 8 bytes).
 *
 * Spec behaviour: with G=1 the lowest bit of pmpaddr is ignored, so the
 * boundary of a TOR entry is ((pmpaddr & ~1) << 2).  This core instead
 * computes (pmpaddr << 2) (see core/pmp/src/pmp_entry.sv), so writing a
 * pmpaddr whose lowest bit is set pushes the boundary up by 4 bytes.
 * A U-mode access in the 4-byte window just below that boundary is then
 * checked against the previous entry instead of the entry it belongs to.
 *
 * PMP configuration (done in M-mode):
 *   entry 0: TOR [0, 0x80000104)      no permissions,  pmpaddr0 = 0x20000041 (odd)
 *   entry 1: TOR [0x80000104, top)    RWX,            pmpaddr1 = -1
 *
 * On a spec-conformant core the entry-0/entry-1 boundary is
 * (0x20000041 & ~1) << 2 = 0x80000100, so the U-mode byte load below at
 * 0x80000102 (inside the [0x80000100, 0x80000104) window) is permitted by
 * entry 1 and the test ends with PASS.  On this core the address still
 * falls into the no-permission entry 0, so the load raises a PMP access
 * fault (mcause 5) and the test fails.
 *
 * Note: on success the PASS tohost store is emitted from U-mode .text
 * (which lies in entry 1's range) rather than by jumping to _halt in
 * .text.init: that region sits inside the deny range and must not be
 * executed in U-mode.
 */
#include "test.h"

  .globl test_main
test_main:
  /* pmpcfg0: entry1 = 0x1f (TOR|RWX), entry0 = 0x08 (TOR|no permissions) */
  li t0, 0x1f08
  csrw pmpcfg0, t0
  /* Note: entries 4..7 keep their reset value (OFF) and are left alone;
   * odd-indexed pmpcfg CSRs (pmpcfg1) are not writable in this RV64 core. */

  /* odd pmpaddr0 -> shifted boundary on the buggy core */
  li t0, 0x20000041
  csrw pmpaddr0, t0
  li t0, -1
  csrw pmpaddr1, t0           /* entry 1 extends to the top of memory */

  /* enter U-mode; the boundary load below is PMP-checked there */
  ENTER_MODE(0, u_boundary_load)

/* U-mode */
u_boundary_load:
  li t0, 0x80000102
  lb a0, 0(t0)                 /* legal on a correct core (entry 1), PMP fault here */

  /* success: report PASS (tohost = 1) without executing code in .text.init */
  la t0, tohost
  li a0, 1
  sd a0, 0(t0)
1: j 1b

/* Report the trap cause so the failure is identifiable: on the buggy core
 * the U-mode boundary load raises a load access fault (mcause = 5). */
  .align 2
  .globl trap_handler
trap_handler:
  csrr a0, mcause
  slli a0, a0, 1
  ori a0, a0, 1
  j _halt
