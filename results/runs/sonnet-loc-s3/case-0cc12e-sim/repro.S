#include "test.h"
  .globl test_main
test_main:
  # 1: jalr clears bit 0
  la t1, 1f
  addi t1, t1, 1
  jalr t2, 0(t1)
  FAIL(1)
1:
  # 2: jalr rd==rs1
  la t1, 2f
  jalr t1, 0(t1)
  FAIL(2)
2:
  la t3, 2b
  bne t1, t3, 3f
  FAIL(3)
3:
  # 3: jalr link value
  la t1, 4f
  jalr t2, 0(t1)
4:
  la t3, 4b
  addi t3, t3, -4
  # skip: link = addr of jalr+4 = 4b
  la t3, 4b
  bne t2, t3, bad4
  # 4: jalr negative imm
  la t1, 5f+16
  jalr t2, -16(t1)
  FAIL(5)
5:
  # 5: branches
  li t0, -1
  li t1, 1
  blt t0, t1, 6f
  FAIL(6)
6:
  bltu t1, t0, 7f
  FAIL(7)
7:
  bge t1, t0, 8f
  FAIL(8)
8:
  bgeu t0, t1, 9f
  FAIL(9)
9:
  beq t0, t0, 10f
  FAIL(10)
10:
  bne t0, t1, 11f
  FAIL(11)
11:
  bge t0, t1, bad12
  bgeu t1, t0, bad13
  blt t1, t0, bad14
  bltu t0, t1, bad15
  beq t0, t1, bad16
  bne t0, t0, bad17
  # jal link
  jal t2, 12f
12:
  la t3, 12b
  bne t2, t3, bad18
  # jal backward
  .option push
  .option norvc
  jal t2, 13f
  FAIL(19)
13:
  la t3, 14f
  jalr t3, 0(t3)
14:
  .option pop
  PASS
bad4: FAIL(4)
bad12: FAIL(12)
bad13: FAIL(13)
bad14: FAIL(14)
bad15: FAIL(15)
bad16: FAIL(16)
bad17: FAIL(17)
bad18: FAIL(18)
