#include "test.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  la t0, trap_handler
  csrw mtvec, t0
  /* set MPRV; mret to S-mode must clear it (MPP != M) */
  li t0, (1 << 17)
  csrs mstatus, t0
  ENTER_MODE(1, s_code)

s_code:
  ecall
  FAIL(2)

  .align 4
  .globl trap_handler
trap_handler:
  csrr t1, mcause
  li t2, 9            /* ecall from S */
  bne t1, t2, 1f
  csrr t1, mstatus
  li t2, (1 << 17)
  and t1, t1, t2
  bnez t1, 2f
  PASS
1:
  FAIL(3)
2:
  FAIL(4)
