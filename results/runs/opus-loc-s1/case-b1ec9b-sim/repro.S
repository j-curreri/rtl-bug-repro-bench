#include "test.h"

/* With PMP granularity G=1 (8 bytes), no pmpaddr bits are forced in NAPOT mode
 * (only bits [G-2:0] read as ones, an empty range). A NAPOT entry whose pmpaddr
 * has bit 0 clear (an 8-byte region) must read back exactly as written. */
  .text
  .globl test_main
test_main:
  /* entry 1: NAPOT, R only; entry 0: OFF */
  li t0, (0x19 << 8)
  csrw pmpcfg0, t0
  li t1, 0x20000010           /* bit 0 = 0 -> 8-byte NAPOT region */
  csrw pmpaddr1, t1
  csrr t2, pmpaddr1
  bne t1, t2, fail1

  /* sanity: same value in TOR mode must also read back unchanged */
  li t0, (0x09 << 8)
  csrw pmpcfg0, t0
  csrr t2, pmpaddr1
  bne t1, t2, fail2

  PASS
fail1:
  FAIL(1)
fail2:
  FAIL(2)
