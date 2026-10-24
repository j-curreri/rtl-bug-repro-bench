#include "test.h"
.globl test_main
.globl trap_handler
trap_handler:
  csrr s1, mstatus
  csrr t0, mcause
  addi t0, t0, -8
  andi t0, t0, -2
  li t1, 0
  bne t0, t1, bad9
  jr s2
test_main:
  PMP_ALLOW_ALL
  # mret to S with mprv=1, mie=1, mpie=0
  li t0, (3<<11)|(1<<17)|(1<<7)
  csrc mstatus, t0
  li t0, (1<<11)|(1<<17)|(1<<3)
  csrs mstatus, t0
  la s2, 3f
  la t0, 2f
  csrw mepc, t0
  mret
2:
  ecall
3:
  # after ecall: mpp=S(1), mprv must be 0, mpie = 0 (mie was... after mret mie=mpie=0, trap saves mie=0)
  li t0, (1<<17)
  and t2, s1, t0
  bnez t2, bad2
  li t0, (1<<3)
  and t2, s1, t0
  bnez t2, bad5
  # mret to U, mie
  li t0, (3<<11)
  csrc mstatus, t0
  li t0, (1<<7)
  csrs mstatus, t0
  la s2, 4f
  la t0, 5f
  csrw mepc, t0
  mret
5:
  ecall
4:
  # mie should be 1 -> mpie after trap = 1; mpp = U
  li t0, (1<<7)
  and t2, s1, t0
  beqz t2, bad6
  li t0, (3<<11)
  and t2, s1, t0
  bnez t2, bad7
  PASS
bad2: FAIL(2)
bad5: FAIL(5)
bad6: FAIL(6)
bad7: FAIL(7)
bad9: FAIL(9)
