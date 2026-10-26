#include "test.h"

/* Reproducer: with mcounteren.CY=1 and scounteren.CY=0, U-mode access to the
 * cycle CSR must raise an illegal-instruction exception (privileged spec, 3.1.11 and
 * 9.6.1 / counter-enable rules: U-mode needs both mcounteren and scounteren).
 * The buggy core checks ~mcounteren & ~scounteren for non-virtual U-mode, so
 * the read succeeds and the ecall below is taken instead. */

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  li t0, 1                 # mcounteren.CY = 1
  csrw mcounteren, t0
  csrw scounteren, zero    # scounteren.CY = 0
  ENTER_MODE(0, u_code)

u_code:
  csrr t0, cycle           # must trap: scounteren.CY = 0
  ecall                    # only reached on the buggy core
  FAIL(2)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 2                 # illegal instruction is the expected trap
  bne t0, t1, 1f
  PASS
1:
  FAIL(1)
