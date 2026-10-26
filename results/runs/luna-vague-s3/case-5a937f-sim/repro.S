#include "test.h"

  .section .text
  .globl test_main
test_main:
  # MENVCFG.CBIE is bits 5:4. 2'b10 is reserved by Zicbom and is not a
  # legal WARL value. Write it and make sure the CSR returns a legal value.
  li   t0, 0x20
  csrw menvcfg, t0
  csrr t1, menvcfg
  andi t1, t1, 0x30
  li   t2, 0x20
  beq  t1, t2, bad_value

  PASS

bad_value:
  FAIL(1)

  .globl trap_handler
  .align 2
trap_handler:
  # An unexpected exception (including a failed CSR access) is a failure.
  FAIL(127)
