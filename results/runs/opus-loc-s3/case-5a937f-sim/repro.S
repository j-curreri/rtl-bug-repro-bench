#include "test.h"

/* U-mode (V=0) access to the cycle counter with mcounteren.CY=1 but
 * scounteren.CY=0 must raise an illegal-instruction exception
 * (privileged spec, "Counter-Enable Registers"). */

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  li t0, -1
  csrw mcounteren, t0      /* allow S/U access per M */
  csrw scounteren, zero    /* but deny U access per S */
  ENTER_MODE(0, user_code)

user_code:
  csrr a1, cycle           /* must trap: illegal instruction */
  ecall                    /* reached only if the read did not trap */

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 2                 /* illegal instruction */
  beq t0, t1, 1f
  li t1, 8                 /* ecall from U: cycle read was allowed */
  beq t0, t1, 2f
  FAIL(3)
1:
  PASS
2:
  FAIL(1)
