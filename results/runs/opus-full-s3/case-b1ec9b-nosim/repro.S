#include "test.h"

#define MSTATUS_MPRV (1 << 17)

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  csrw satp, zero
  /* Set MPRV, then mret to S-mode: the spec requires MPRV to be cleared. */
  li t0, MSTATUS_MPRV
  csrs mstatus, t0
  ENTER_MODE(1, s_code)

s_code:
  ecall                     /* return to M-mode */
  FAIL(2)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 9                  /* ecall from S-mode */
  bne t0, t1, bad_trap
  csrr t0, mstatus
  li t1, MSTATUS_MPRV
  and t0, t0, t1
  bnez t0, mprv_stuck
  PASS
mprv_stuck:
  FAIL(1)
bad_trap:
  FAIL(3)
