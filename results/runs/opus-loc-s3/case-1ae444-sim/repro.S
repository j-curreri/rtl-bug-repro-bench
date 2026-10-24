/* PMP granularity is G=1 (8 bytes): with A=OFF/TOR only pmpaddr[0] reads as 0.
 * Per the privileged spec, for NAPOT only bits [G-2:0] read as ones, i.e. none
 * when G=1, so a NAPOT pmpaddr must read back exactly what was written.
 * The buggy core forces pmpaddr[0] to 1 on reads of NAPOT entries. */
#include "test.h"
  .option norvc
  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL                 /* entry 0: NAPOT RWX over everything */

  /* Sanity: G=1 -> OFF entry clears only bit 0 of an all-ones write. */
  li t0, -1
  csrw pmpaddr1, t0
  csrr t1, pmpaddr1
  andi t2, t1, 3
  li t3, 2
  bne t2, t3, skip_g1           /* granularity is not G=1: nothing to test */

  /* Entry 1: NAPOT, R only, unlocked (does not affect M-mode). */
  li t0, 0x20001000             /* even value: 8-byte NAPOT region */
  csrw pmpaddr1, t0
  li t1, (0x19 << 8) | 0x1f
  csrw pmpcfg0, t1
  csrr t2, pmpcfg0
  bne t2, t1, skip_g1
  csrr t2, pmpaddr1
  bne t2, t0, fail1

  /* Writing again while NAPOT is active must also read back unchanged. */
  li t0, 0x20002010
  csrw pmpaddr1, t0
  csrr t2, pmpaddr1
  bne t2, t0, fail2

skip_g1:
  csrw pmpcfg0, zero
  li t0, 0x1f
  csrw pmpcfg0, t0
  PASS
fail1:
  FAIL(1)
fail2:
  FAIL(2)
