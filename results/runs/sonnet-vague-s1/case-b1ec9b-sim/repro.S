#include "test.h"
.globl test_main
test_main:
  PMP_ALLOW_ALL
  # case 1: MPP=M, MPRV=1 stays 1, MPP becomes U, MPIE=1
  li t0, (3<<11)|(1<<17)|(1<<7)
  csrs mstatus, t0
  la t0, 1f
  csrw mepc, t0
  mret
1:
  csrr t1, mstatus
  li t2, (1<<17)
  and t3, t1, t2
  beqz t3, fail1
  li t2, (3<<11)
  and t3, t1, t2
  bnez t3, fail2
  # case 2: MPP=S, MPRV=1 -> MPRV cleared
  li t0, (3<<11)
  csrc mstatus, t0
  li t0, (1<<11)|(1<<17)
  csrs mstatus, t0
  la t0, 2f
  csrw mepc, t0
  mret
2:
  # now in S; ecall back
  ecall
.align 2
fail1: FAIL(1)
fail2: FAIL(2)
.globl trap_handler
trap_handler:
  csrr t1, mstatus
  li t2, (1<<17)
  and t3, t1, t2
  bnez t3, f3
  li t2, (3<<11)
  and t3, t1, t2
  li t2, (1<<11)
  bne t3, t2, f4
  li t2, (1<<7)
  and t3, t1, t2
  # after trap from S: MPP=S(1)
  PASS
f3: FAIL(3)
f4: FAIL(4)
