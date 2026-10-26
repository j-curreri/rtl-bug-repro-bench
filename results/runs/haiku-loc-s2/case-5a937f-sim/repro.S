#include "test.h"

/* U-mode access to the cycle counter needs mcounteren.CY AND scounteren.CY.
 * Here mcounteren.CY = 1 and scounteren.CY = 0, so the read must raise an
 * illegal-instruction exception (mcause = 2). A core that lets the read
 * through never traps; the ecall below then reaches the handler instead. */

  .section .text
  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 2              # illegal instruction: the expected outcome
  beq t0, t1, 1f
  FAIL(2)               # any other trap (e.g. ecall from U-mode): read was allowed

1:
  PASS

  .globl test_main
test_main:
  PMP_ALLOW_ALL
  li t0, 1              # mcounteren.CY
  csrw mcounteren, t0
  csrw scounteren, zero
  ENTER_MODE(0, u_code)

  .align 2
u_code:
  csrr t0, cycle
  ecall
