#include "test.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* Set mstatus.MPRV, then return to U-mode. MRET to a mode other than M must clear MPRV. */
  li t0, (1 << 17)
  csrs mstatus, t0
  ENTER_MODE(0, user_code)

user_code:
  ecall
  FAIL(2)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 8                  /* ecall from U-mode */
  bne t0, t1, 1f
  csrr t0, mstatus
  li t1, (1 << 17)
  and t0, t0, t1
  bnez t0, 2f
  PASS
2: FAIL(1)                  /* MPRV still set after MRET to U-mode */
1: FAIL(3)                  /* unexpected trap cause */
