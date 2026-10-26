#include "test.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  /* UBE is a WARL control for explicit U-mode data accesses. */
  csrw mstatus, zero
  li t0, (1 << 6)
  csrw mstatus, t0
  csrr t1, mstatus
  andi t1, t1, (1 << 6)
  beqz t1, failed
  PASS

failed:
  FAIL(1)

  .globl trap_handler
trap_handler:
  FAIL(2)
