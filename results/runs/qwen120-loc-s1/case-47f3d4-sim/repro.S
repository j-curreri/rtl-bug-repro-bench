/* repro.S: mcounntinhibit bit 2 must not freeze minstret.
 *
 * Zihpm: mcounntinhibit bit 0 inhibits cycle, bit 1 inhibits instret,
 * bit N (N >= 2) inhibits hpmcounterN.  On this core the commit logic
 * (core/csr_regfile.sv, instret update) gates the minstret increment on
 * mcountinhibit[2] instead of mcountinhibit[1], so writing
 * mcounntinhibit = 4 (the hpmcounter2 inhibit bit, which does not exist
 * on a core whose hpmcounters start at hpmcounter3) freezes minstret.
 *
 * A spec-conformant core keeps counting instret when only bit 2 is set,
 * so on that core this test ends with PASS.
 *
 * Note: bit 2 is not read back as a hard check -- for a hart without
 * hpmcounter2 the spec permits that bit to be WARL read-only zero.  The
 * discriminator is purely the minstret behaviour.
 *
 * Result codes: 1=baseline broken (minstret frozen with mcountinhibit=0),
 *               2=minstret frozen while only bit 2 is set (the bug).
 */
#include "test.h"

  .section .text
  .globl test_main
test_main:
  /* phase 1 (sanity): minstret must advance with mcounntinhibit = 0 */
  li t0, 0
  csrw mcountinhibit, t0
  csrr s0, minstret
  li t0, 400
lp0: addi t0, t0, -1
     bnez t0, lp0
  csrr s1, minstret
  sub s2, s1, s0
  beqz s2, fail_base

  /* phase 2: set only bit 2 (hpmcounter inhibit, NOT the instret bit) */
  li t0, 4
  csrw mcountinhibit, t0
  csrr s0, minstret
  li t0, 400
lp1: addi t0, t0, -1
     bnez t0, lp1
  csrr s1, minstret
  sub s2, s1, s0
  li t0, 0
  csrw mcountinhibit, t0
  beqz s2, fail_frozen

  PASS

fail_base:  FAIL(1)
fail_frozen: FAIL(2)
