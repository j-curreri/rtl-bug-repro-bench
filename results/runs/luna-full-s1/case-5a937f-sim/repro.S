#include "test.h"

  .section .text
  .globl test_main
test_main:
  /* Run the lower-privilege check with access to the harness memory. */
  PMP_ALLOW_ALL

  /* menvcfg.CBIE is bits 5:4. 2'b10 is reserved and must not stick. */
  csrr t0, menvcfg
  li   t1, -49                 /* clear bits 5:4 */
  and  t0, t0, t1
  ori  t0, t0, 0x20
  csrw menvcfg, t0
  csrr t0, menvcfg
  andi t0, t0, 0x30
  li   t1, 0x20
  beq  t0, t1, fail_m

  /* henvcfg.CBIE has the same WARL encodings. */
  csrr t0, henvcfg
  li   t1, -49
  and  t0, t0, t1
  ori  t0, t0, 0x20
  csrw henvcfg, t0
  csrr t0, henvcfg
  andi t0, t0, 0x30
  li   t1, 0x20
  beq  t0, t1, fail_h

  /* Exercise senvcfg from S-mode. */
  ENTER_MODE(1, test_senvcfg)

test_senvcfg:
  csrr t0, senvcfg
  li   t1, -49
  and  t0, t0, t1
  ori  t0, t0, 0x20
  csrw senvcfg, t0
  csrr t0, senvcfg
  andi t0, t0, 0x30
  li   t1, 0x20
  beq  t0, t1, fail_s

  PASS

fail_m:
  FAIL(1)
fail_h:
  FAIL(2)
fail_s:
  FAIL(3)
