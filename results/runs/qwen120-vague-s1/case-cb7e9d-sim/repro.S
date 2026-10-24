#include "test.h"

/*
 * Bug: some Sdtrig (mcontrol6) ADDRESS-match triggers do not fire when the spec
 * says they should.  Specifically the nAPOT matcher (triggers_pkg::napot_match64)
 * only accepts a trigger value `base` when `(base & (base + 1)) == 0` (i.e.
 * base == 2^k - 1) and otherwise always reports "no match".  A spec-conformant
 * nAPOT region, however, always contains its own base address, so a trigger whose
 * tdata2 equals the address being accessed MUST fire.
 *
 * This program arms an mcontrol6 LOAD-ADDRESS trigger with match = nAPOT and
 * tdata2 = the address of `data_word`, then performs a load from that exact
 * address:
 *
 *   - correct core : the nAPOT region of tdata2 contains tdata2 -> the load
 *                    raises a breakpoint (mcause = 3) -> trap_handler PASSes.
 *   - buggy core   : napot_match64(tdata2, tdata2) == 0 -> the load completes
 *                    normally, the trigger never fires -> we reach FAIL(5).
 *
 * A load trigger is used rather than an execute trigger so the trigger address
 * sits in .data (far from the code), and the trap handler issues no loads, so
 * the trigger cannot re-fire inside the handler.
 */

  .section .text
  .globl test_main
  .align 2
test_main:
  /*
   * Configure trigger 0 as an mcontrol6 load-address trigger:
   *   ttype = 6   (bits [63:60], mcontrol6)
   *   m     = 1   (bit 6)
   *   match = 1   (bits [10:7] = 4'b0001, nAPOT -> bit 7)
   *   load  = 1   (bit 0)
   *   select    = 0  (match on address, not data)
   *   action    = 0  (breakpoint)
   *   => tdata1 = 0x60000000000000C1
   */
  li t0, 0
  csrw tselect, t0
  li t1, 0x60000000000000C1
  csrw tdata1, t1

  /* tdata2 = the address of data_word (a normal, non-2^k-1 address). */
  la t1, data_word
  csrw tdata2, t1

  /*
   * This load's address equals tdata2, so on a spec-conformant core it must hit
   * the nAPOT trigger and raise a breakpoint.  If we reach the FAIL below the
   * trigger never fired.
   */
  ld t2, 0(t1)
  FAIL(5)                 /* mcontrol6 nAPOT address trigger did not fire */

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 3                /* riscv::BREAKPOINT */
  bne t0, t1, fail_other
  PASS                    /* expected breakpoint from the address-match trigger */
fail_other:
  FAIL(128)               /* some unexpected trap */

  .section .data
  .align 3
data_word:
  .dword 0x1234567890abcdef
