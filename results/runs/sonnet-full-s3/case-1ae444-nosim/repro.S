#include "test.h"
.text
.globl test_main
.globl trap_handler
.align 2
test_main:
  la t0, trap_handler
  csrw mtvec, t0
  li s0, 0x02000000       # msip
  li s1, 0                # iteration counter
  li s2, 8
1:
  li t0, -1
  csrw mtval, t0          # poison mtval
  li t0, 0x8
  csrs mie, t0            # MSIE
  csrsi mstatus, 8        # MIE
  li t1, 1
  sw t1, 0(s0)            # raise msip
  # varied instruction mix while interrupt is pending
  addi a1, a1, 1
  .rept 4
  add a2, a2, a1
  xor a3, a2, a1
  c.nop
  mul a4, a3, a2
  .endr
  .rept 64
  nop
  .endr
  csrci mstatus, 8
  # handler records result in s3 (mtval) and sets s4 = 1
  li t0, 1
  bne s4, t0, fail_nointr
  bnez s3, fail_mtval
  li s4, 0
  addi s1, s1, 1
  blt s1, s2, 1b
  PASS
fail_nointr:
  FAIL(1)
fail_mtval:
  FAIL(2)

.align 2
trap_handler:
  csrr t0, mcause
  bgez t0, bad
  csrr s3, mtval
  li s4, 1
  sw zero, 0(s0)          # clear msip
  mret
bad:
  FAIL(3)
