#include "test.h"
  .text
  .globl trap_handler
  .align 2
trap_handler:
  csrr s11, mcause
  csrr s10, mepc
  addi s10, s10, 4
  csrw mepc, s10
  mret

  .globl test_main
test_main:
  li s11, 0
  # 1: JAL link
  jal ra, 1f
1:la t0, 1b
  bne ra, t0, f1
  # 2: JALR odd target, link
  la t1, 2f
  addi t1, t1, 1
  jalr ra, 0(t1)
  j f2
2: la t0, 2b
  # 3: jalr rd==rs1
  la t1, 3f
  jalr t1, 0(t1)
3: la t0, 3b
  bne t1, t0, f3
  # 4: jalr negative imm
  la t1, 4f+8
  jalr x0, -8(t1)
  j f4
4:
  # 5: branches
  li a1, -1
  li a2, 1
  blt a2, a1, f5
  bge a1, a2, f5
  bltu a1, a2, f5
  bgeu a2, a1, f5
  beq a1, a2, f5
  bne a1, a1, f5
  blt a1, a2, 5f
  j f5
5: bge a2, a1, 5f
  j f5
5: bltu a2, a1, 5f
  j f5
5: bgeu a1, a2, 5f
  j f5
5: bge a1, a1, 5f
  j f5
5: bgeu a1, a1, 5f
  j f5
5: beq a1, a1, 5f
  j f5
5: bne a1, a2, 5f
  j f5
5:
  # 6: illegal branch funct3 010
  li s11, 0
  .word 0x00002063   # funct3=010 branch, offset 0
  li t0, 2
  bne s11, t0, f6
  li s11, 0
  .word 0x00003063
  li t0, 2
  bne s11, t0, f7
  # 8: illegal jalr funct3
  li s11, 0
  la t1, 8f
  .word 0x000310e7 | (0 << 20)  # jalr ra, 0(t1) funct3=001 -> t1=x6: rs1=6
8: li t0, 2
  bne s11, t0, f8
  # 9: compressed
  .option push
  .option rvc
  li a3, 0
  c.beqz a3, 9f
  j f9
9: c.bnez a3, f9
  la t1, 9f
  c.jalr t1
9: la t0, 9b
  bne ra, t0, f9
  .option pop
  PASS
f1: FAIL(1)
f2: FAIL(2)
f3: FAIL(3)
f4: FAIL(4)
f5: FAIL(5)
f6: FAIL(6)
f7: FAIL(7)
f8: FAIL(8)
f9: FAIL(9)
