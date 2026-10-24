/* PMP granularity G=1 (8 bytes): with pmpcfg.A=NAPOT, pmpaddr bit 0 encodes an
 * 8-byte region and must read back as written (only G>=2 forces low bits to 1).
 * The buggy core forces bit 0 to 1 on read in NAPOT mode. */
#include "test.h"
  .text
  .globl test_main
test_main:
  // entry 0: NAPOT, RWX, 8-byte region at 0x80001000 (pmpaddr bit 0 = 0)
  li t0, (0x80001000 >> 2)
  csrw pmpaddr0, t0
  li t0, 0x1f
  csrw pmpcfg0, t0
  csrr t1, pmpaddr0
  li t0, (0x80001000 >> 2)
  bne t1, t0, fail1
  // same in OFF mode reads back as written too (bit 0 already 0)
  csrw pmpcfg0, zero
  csrr t1, pmpaddr0
  bne t1, t0, fail2
  PASS
fail1:
  FAIL(1)
fail2:
  FAIL(2)
