#include "test.h"
#include "hyp.h"

  .globl test_main
test_main:
  PMP_ALLOW_ALL
  la t0, trap_handler_m
  csrw mtvec, t0
  # MPRV=1, MPP=S, mret to S-mode
  li t0, (1 << 17)
  csrs mstatus, t0
  ENTER_MODE(1, smode)

smode:
  ecall

  .align 2
trap_handler_m:
  csrr t0, mcause
  li t1, 9
  bne t0, t1, bad
  csrr t0, mstatus
  li t1, (1 << 17)
  and t0, t0, t1
  bnez t0, bad
  PASS
bad:
  FAIL(1)

  .globl trap_handler
trap_handler:
  j bad
