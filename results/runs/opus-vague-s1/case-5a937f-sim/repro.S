#include "test.h"

/* menvcfg/senvcfg.CBIE (bits 5:4) is WARL; 0b10 is reserved and must never read back. */
  .text
  .globl test_main
test_main:
  li t1, 0x30
  li t2, 0x20

  /* menvcfg */
  csrc menvcfg, t1
  csrs menvcfg, t2
  csrr t0, menvcfg
  and t0, t0, t1
  beq t0, t2, fail_m

  /* senvcfg */
  csrc senvcfg, t1
  csrs senvcfg, t2
  csrr t0, senvcfg
  and t0, t0, t1
  beq t0, t2, fail_s

  PASS
fail_m:
  FAIL(1)
fail_s:
  FAIL(2)
