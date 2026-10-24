#include "harness/test.h"
#include "harness/hyp.h"
  .globl test_main
  .globl trap_handler
test_main:
  PMP_ALLOW_ALL
  csrw satp, zero
  li t0, (1 << 17)          # MPRV=1
  csrs mstatus, t0
  ENTER_MODE(1, s_code)
s_code:
  ecall
1:
  j 1b
  .align 2
trap_handler:
  csrr t1, mcause
  li t2, 9
  bne t1, t2, bad
  csrr t1, mstatus
  li t2, (1 << 17)
  and t1, t1, t2
  bnez t1, bad
  PASS
bad:
  FAIL(1)
