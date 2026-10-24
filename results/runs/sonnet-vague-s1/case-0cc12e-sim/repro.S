#include "test.h"
.option norvc
.globl test_main
.globl trap_handler
.text
trap_handler:
  csrr s1, mcause
  csrr s2, mtval
  csrr s3, mepc
  csrr s4, mstatus
  addi s5, s5, 1
  la t0, retaddr
  ld t1, 0(t0)
  bnez t1, 1f
  addi s3, s3, 4
  csrw mepc, s3
  mret
1: csrw mepc, t1
  sd zero, 0(t0)
  mret
test_main:
  la t0, trap_handler
  csrw mtvec, t0
  PMP_ALLOW_ALL
  li s5, 0
  # misaligned load
  la t6, buf
  addi t6, t6, 1
  lw a1, 0(t6)
  li t0, 4
  bne s1, t0, f1
  bne s2, t6, f2
  # misaligned store
  la t6, buf
  addi t6, t6, 2
  sw a1, 0(t6)
  li t0, 6
  bne s1, t0, f7
  bne s2, t6, f8
  # ecall
  ecall
  li t0, 11
  bne s1, t0, f9
  # ebreak
  ebreak
  li t0, 3
  bne s1, t0, f11
  # fetch fault
  la t0, retaddr
  la t1, back
  sd t1, 0(t0)
  li t6, 0x1000
  jr t6
back:
  li t0, 1
  bne s1, t0, f12
  li t0, 0x1000
  bne s2, t0, f13
  PASS
f1: slli a0,s1,8; ori a0,a0,1; j _halt
f2: FAIL(2)
f3: slli a0,s1,8; ori a0,a0,1; j _halt
f4: slli a0,s2,8; ori a0,a0,1; j _halt
f5: FAIL(5)
f6: FAIL(6)
f7: FAIL(7)
f8: FAIL(8)
f9: FAIL(9)
f10: FAIL(10)
f11: FAIL(11)
f12: FAIL(12)
f13: FAIL(13)
.data
.align 3
retaddr: .dword 0
buf: .dword 0,0
