#include "harness/test.h"
.globl test_main
.globl trap_handler
test_main:
  PMP_ALLOW_ALL
  la t0, trap_handler
  csrw mtvec, t0
  li t0, 128
  csrs mstatus, t0
  li t0, 8
  csrc mstatus, t0
  ENTER_MODE(1, 1f)
1:
  ecall
trap_handler:
  csrr t4, mcause
  li t5, 9
  beq t4, t5, 4f
  FAIL(3)
4:
  csrr t1, mstatus
  li t2, 0x80
  and t3, t1, t2
  bnez t3, 5f
  FAIL(4)
5:
  PASS
