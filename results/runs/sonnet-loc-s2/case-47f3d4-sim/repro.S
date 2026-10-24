#include "test.h"
.text
.globl test_main
.globl trap_handler
test_main:
  PMP_ALLOW_ALL
  li t0, 1
  csrw mcounteren, t0
  csrw scounteren, zero
  ENTER_MODE(0, umode)
.align 2
umode:
  csrr t1, cycle        # must trap: scounteren.CY = 0
  ecall                 # reached only if no trap
trap_handler:
  csrr t0, mcause
  li t1, 2
  bne t0, t1, bad
  PASS
bad:
  FAIL(1)
