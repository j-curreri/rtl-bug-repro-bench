#include "test.h"

  .section .text
  .globl test_main
test_main:
  # menvcfg.CBIE is bits [5:4]. Encoding 2 is reserved by the ISA.
  li t0, 0x20
  csrw menvcfg, t0
  csrr t1, menvcfg
  andi t1, t1, 0x30
  li t2, 0x20
  beq t1, t2, fail_reserved_cbie

  PASS

fail_reserved_cbie:
  FAIL(1)

  .globl trap_handler
trap_handler:
  FAIL(127)
