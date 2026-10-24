#include "test.h"
.globl test_main
.globl trap_handler
.text
test_main:
  PMP_ALLOW_ALL
  la t0, trap_handler
  csrw mtvec, t0
  li t0, 0x08
  csrc mstatus, t0   # MIE=0
  li t0, 0x80
  csrc mstatus, t0   # MPIE=0 => MIE=0 after mret
  li t0, 8
  csrw mie, t0
  li t1, 0x02000000
  li t2, 1
  sw t2, 0(t1)
  ENTER_MODE(0, loop_s)
loop_s:
  li t3, 3000
1: addi t3,t3,-1
  bnez t3,1b
  FAIL(1)
trap_handler:
  csrr t0, mstatus
  andi t0, t0, 0x88
  bnez t0, f2        # MPIE must be 0 (was MIE in U? MIE=0 -> MPIE=0) and MIE=0
  PASS
f2: FAIL(2)
