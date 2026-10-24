/* MRET to S-mode must clear mstatus.MPRV (priv spec: xRET to a mode less than M clears MPRV). */
#include "test.h"
#define MSTATUS_MPRV (1 << 17)
  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  li t0, MSTATUS_MPRV
  csrs mstatus, t0
  ENTER_MODE(1, in_smode)
in_smode:
  ecall

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 9                     /* ecall from S-mode */
  bne t0, t1, 1f
  csrr t0, mstatus
  li t1, MSTATUS_MPRV
  and t0, t0, t1
  bnez t0, 2f
  PASS
1: FAIL(1)
2: FAIL(2)
