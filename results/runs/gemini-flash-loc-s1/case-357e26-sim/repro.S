#include "test.h"

  .globl trap_handler
trap_handler:
  /* Unexpected trap */
  csrr a0, mcause
  FAIL(a0)

  .globl test_main
test_main:
  /* Test 1: Entry 0 allow all, test basic U-mode execution */
  PMP_ALLOW_ALL
  ENTER_MODE(0, test_1_passed)

test_1_passed:
  PASS
