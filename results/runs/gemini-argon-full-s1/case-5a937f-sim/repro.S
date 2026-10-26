#include "test.h"

#define CBIE_MASK 0x30
#define CBIE_RSVD 0x20

  .text
  .globl test_main
test_main:
  li   s0, CBIE_RSVD

  /* 1. menvcfg.CBIE: WARL field (bits 5:4), 2'b10 is reserved and must never read back. */
  csrr t0, menvcfg
  andi t1, t0, ~CBIE_MASK
  ori  t2, t1, CBIE_RSVD
  csrw menvcfg, t2
  csrr t3, menvcfg
  andi t3, t3, CBIE_MASK
  beq  t3, s0, fail_menvcfg

  csrw menvcfg, t1
  csrs menvcfg, s0
  csrr t3, menvcfg
  andi t3, t3, CBIE_MASK
  beq  t3, s0, fail_menvcfg

  ori  t2, t1, CBIE_MASK
  csrw menvcfg, t2
  csrci menvcfg, 0x10
  csrr t3, menvcfg
  andi t3, t3, CBIE_MASK
  beq  t3, s0, fail_menvcfg

  /* 2. senvcfg.CBIE: WARL field (bits 5:4), 2'b10 is reserved and must never read back. */
  csrr t0, senvcfg
  andi t1, t0, ~CBIE_MASK
  ori  t2, t1, CBIE_RSVD
  csrw senvcfg, t2
  csrr t3, senvcfg
  andi t3, t3, CBIE_MASK
  beq  t3, s0, fail_senvcfg

  csrw senvcfg, t1
  csrs senvcfg, s0
  csrr t3, senvcfg
  andi t3, t3, CBIE_MASK
  beq  t3, s0, fail_senvcfg

  ori  t2, t1, CBIE_MASK
  csrw senvcfg, t2
  csrci senvcfg, 0x10
  csrr t3, senvcfg
  andi t3, t3, CBIE_MASK
  beq  t3, s0, fail_senvcfg

  /* 3. henvcfg.CBIE (if the H extension is implemented). */
  csrr t0, misa
  andi t0, t0, (1 << 7)
  beqz t0, done

  csrr t0, henvcfg
  andi t1, t0, ~CBIE_MASK
  ori  t2, t1, CBIE_RSVD
  csrw henvcfg, t2
  csrr t3, henvcfg
  andi t3, t3, CBIE_MASK
  beq  t3, s0, fail_henvcfg

done:
  PASS

fail_menvcfg:
  FAIL(1)
fail_senvcfg:
  FAIL(2)
fail_henvcfg:
  FAIL(3)
