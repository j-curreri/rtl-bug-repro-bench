/* PMP granularity here is G=1 (8 bytes: NA4 is not selectable).
 * Per the privileged spec, for G=1 no pmpaddr bits are forced in NAPOT
 * mode (bits [G-2:0] is an empty range); only OFF/TOR force bit [G-1:0]=0.
 * So an even value written to pmpaddr in NAPOT mode must read back unchanged.
 * The buggy core forces pmpaddr[0]=1 on reads in NAPOT mode. */
#include "test.h"
  .text
  .globl test_main
test_main:
  /* pmp1: NAPOT 8-byte region at 0x40, no permissions (M-mode unaffected) */
  li t0, 0x10
  csrw pmpaddr1, t0
  li t0, (0x18 << 8)
  csrw pmpcfg0, t0
  csrr t1, pmpcfg0
  li t2, 0xff00
  and t1, t1, t2
  li t2, (0x18 << 8)
  bne t1, t2, fail1         /* NAPOT must be selectable */

  csrr t1, pmpaddr1
  li t2, 0x10
  bne t1, t2, fail2         /* NAPOT readback must equal written value */

  /* sanity: in TOR mode bit 0 reads as zero, upper bits preserved */
  li t0, 0x11
  csrw pmpaddr1, t0
  li t0, (0x08 << 8)
  csrw pmpcfg0, t0
  csrr t1, pmpaddr1
  li t2, 0x10
  bne t1, t2, fail3

  /* back to NAPOT with odd value: reads back unchanged */
  li t0, (0x18 << 8)
  csrw pmpcfg0, t0
  csrr t1, pmpaddr1
  li t2, 0x11
  bne t1, t2, fail4

  csrw pmpcfg0, zero
  PASS
fail1: FAIL(1)
fail2: FAIL(2)
fail3: FAIL(3)
fail4: FAIL(4)
