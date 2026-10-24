#include "test.h"
.globl test_main
.globl trap_handler
.align 8
trap_handler:
  csrr s0, mcause
  csrr s1, mstatus
  csrr s2, mepc
  # clear msip
  li t0, 0x02000000
  sw x0, 0(t0)
  addi s5, s5, 1
  mret
test_main:
  li s5, 0
  li t0, 8
  csrw mie, t0
  li t0, 0x02000000
  li t1, 1
  sw t1, 0(t0)
  fence
  li t3, 50
9: addi t3,t3,-1
  bnez t3, 9b
  csrr t2, mip
  andi t2, t2, 8
  beqz t2, f1
  csrs mstatus, 8        # MIE
  nop
  nop
  nop
  li t0, 1
  bne s5, t0, f2
  li t0, 0x8000000000000003
  bne s0, t0, f3
  # mstatus in handler: mpie=1, mie=0, mpp=3
  li t0, 0x1888
  and t1, s1, t0
  li t2, 0x1880
  bne t1, t2, f4
  # after mret mie=1
  csrr t1, mstatus
  andi t1, t1, 8
  beqz t1, f5
  # vectored
  la t0, vec
  ori t0, t0, 1
  csrw mtvec, t0
  li t0, 0x02000000
  li t1, 1
  sw t1, 0(t0)
  fence
  li t3, 50
8: addi t3,t3,-1
  bnez t3, 8b
  nop
  nop
  nop
  nop
  csrr s7, mip
  csrr s8, mstatus
  csrr s9, mie
  li t0, 2
  bne s5, t0, f6
  li t0, 3
  bne s6, t0, f7
  PASS
.align 8
.option push
.option norvc
vec:
  j f10
  j f10
  j f10
  j vec3
  .rept 20
  j f10
  .endr
vec3:
.option pop
  li s6, 3
  li t0, 0x02000000
  sw x0, 0(t0)
  addi s5, s5, 1
  mret
f1: FAIL(1)
f2: FAIL(2)
f3: FAIL(3)
f4: FAIL(4)
f5: FAIL(5)
f6: andi a1,s7,8
  beqz a1, g1
  andi a1,s8,8
  beqz a1,g2
  andi a1,s9,8
  beqz a1,g3
  FAIL(6)
g1: slli a0, s5, 1
  addi a0,a0,100
  slli a0,a0,1
  ori a0,a0,1
  j _halt
  FAIL(20)
g2: FAIL(21)
g3: FAIL(22)
f7: FAIL(7)
f10: FAIL(10)
