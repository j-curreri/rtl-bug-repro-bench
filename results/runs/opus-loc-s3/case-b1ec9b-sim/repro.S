#include "test.h"

/*
 * PMP granularity is G=1 (8 bytes) on this core: pmp_entry treats a NAPOT
 * pmpaddr with bit 0 clear as an 8-byte region. Per the privileged spec,
 * pmpaddr bits are only forced to ones in NAPOT mode when G >= 2, so with
 * G=1 a NAPOT pmpaddr must read back exactly the value written. OFF/TOR read
 * bit 0 as zero.
 */

  .text
  .globl test_main
test_main:
  /* entry 1 OFF: bit 0 reads as zero (G=1) */
  csrw pmpcfg0, zero
  li t0, 0x20000001
  csrw pmpaddr1, t0
  csrr t1, pmpaddr1
  li t2, 0x20000000
  bne t1, t2, fail1

  /* entry 1 NAPOT, 8-byte region at 0x80000000 (pmpaddr bit 0 = 0) */
  li t0, 0x20000000
  csrw pmpaddr1, t0
  li t0, (0x18 << 8)          /* pmp1cfg: A=NAPOT, no RWX (M-mode unaffected) */
  csrw pmpcfg0, t0
  csrr t1, pmpcfg0
  li t2, (0x18 << 8)
  bne t1, t2, fail2
  csrr t1, pmpaddr1
  li t2, 0x20000000
  bne t1, t2, fail3           /* buggy core reads 0x20000001 */

  csrw pmpcfg0, zero
  PASS
fail1: FAIL(1)
fail2: FAIL(2)
fail3: FAIL(3)
