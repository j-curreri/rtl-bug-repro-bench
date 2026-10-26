#include "test.h"

  .section .text
  .globl test_main
  .globl trap_handler
  .align 2
trap_handler:
  FAIL(127)

  .align 2
test_main:
  /* CBIE=2 (bits 5:4) is reserved in the environment-configuration CSRs. */
  li t0, 0x20

  csrw menvcfg, t0
  csrr t1, menvcfg
  andi t1, t1, 0x30
  li t2, 0x20
  beq t1, t2, fail_menvcfg

  csrw senvcfg, t0
  csrr t1, senvcfg
  andi t1, t1, 0x30
  li t2, 0x20
  beq t1, t2, fail_senvcfg

  csrw henvcfg, t0
  csrr t1, henvcfg
  andi t1, t1, 0x30
  li t2, 0x20
  beq t1, t2, fail_henvcfg

  PASS

fail_menvcfg:
  FAIL(1)
fail_senvcfg:
  FAIL(2)
fail_henvcfg:
  FAIL(3)
