#include "test.h"

/*
 * Bug reproducer: Sdtrig mcontrol6 NAPOT (match=1) address-match triggers.
 *
 * The buggy napot_match() helper only considers a trigger "valid" when
 *     tdata2 & (tdata2 + 1) == 0
 * which is true only for encodings of the form 2^n - 1, i.e. NAPOT ranges
 * that start at address 0.  Any NAPOT range whose base is not 0 (so that
 * there is a 1-bit of tdata2 above the run of trailing ones) is rejected and
 * the trigger never fires.  Exact-match (match=0) uses a different path and
 * still works, which is exactly the reported symptom.
 *
 * This test arms trigger 0 as an mcontrol6 load-address trigger with
 * match=1 (NAPOT) covering [0x80000000, 0x80000FFF] (tdata2 = 0x80000FFF)
 * and performs a load inside that range.
 *
 *   - A spec-correct core fires the breakpoint, trap_handler records it, and
 *     the program ends with PASS.
 *   - The buggy core's napot_match returns 0 for this range, so no breakpoint
 *     is ever raised and the program ends with FAIL.
 *
 * The chosen range has base 0x80000000 != 0, so tdata2 & (tdata2+1) != 0 and
 * the buggy validity test rejects it.
 */

  .section .bss
  .align 3
  .globl bp_flag
bp_flag:
  .dword 0

/* Breakpoint taken?  Record it, disarm trigger 0, and return to the load. */
  .section .text
  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li   t1, 3                 /* 3 = breakpoint */
  bne  t0, t1, th_fail
  la   t2, bp_flag
  li   t3, 1
  sd   t3, 0(t2)
  csrw 0x7A0, x0            /* tselect = 0 */
  li   t3, 0xF000000000000000 /* mcontrol6 type field -> 15 (disabled) */
  csrw 0x7A1, t3            /* tdata1 = disabled */
  mret
th_fail:
  FAIL(127)

  .align 2
  .globl test_main
test_main:
  csrci mstatus, 8          /* disable M-mode interrupts */
  PMP_ALLOW_ALL

  csrw 0x7A0, x0            /* tselect = 0 */

  /* mcontrol6: type=6, select=0 (match address), size=0, action=0
   * (breakpoint), match=1 (NAPOT), m=1, load=1  =>  0x60000000000000C1 */
  li t0, 0x60000000000000C1
  csrw 0x7A1, t0            /* tdata1 */

  /* NAPOT range [0x80000000, 0x80000FFF]. */
  li t1, 0x80000FFF
  csrw 0x7A2, t1            /* tdata2 */

  /* Clear the breakpoint flag. */
  la t2, bp_flag
  li t3, 0
  sd t3, 0(t2)

  /* Load inside the armed range.  A correct core takes a breakpoint here. */
  li t4, 0x80000000
  ld t5, 0(t4)              /* <-- trigger point */

  /* Did the breakpoint fire? */
  la t2, bp_flag
  ld t3, 0(t2)
  beqz t3, 1f
  PASS
1:
  FAIL(2)
