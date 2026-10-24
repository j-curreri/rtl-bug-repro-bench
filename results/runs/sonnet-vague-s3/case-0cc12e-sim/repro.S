#include "test.h"
  .option norvc
  .text
  .globl test_main
  .globl trap_handler
  .align 2
trap_handler:
  csrr s1, mcause
  csrr s2, mtval
  csrr s3, mstatus
  csrr t5, mepc
  li t4, 1
  bne s1, t4, 1f
  mv t5, ra
  j 2f
1: addi t5, t5, 4
2: csrw mepc, t5
  mret

#define CHK(n, c, v) \
  li t0, c; bne s1, t0, fail##n; li t0, v; bne s2, t0, fail##n; j ok##n; \
  fail##n: slli a0, s1, 8; ori a0, a0, n;  slli a0, a0, 1; ori a0, a0, 1; j _halt; ok##n:

test_main:
  li t0, ((0x80100000 >> 2) | 0x1ff)
  csrw pmpaddr0, t0
  li t0, -1
  csrw pmpaddr1, t0
  li t0, ((0x1f << 8) | 0x98)
  csrw pmpcfg0, t0
  li s0, 0x80001001
  li t0, 0x6000
  csrs mstatus, t0
  ld t1, 0(s0)
  CHK(1, 4, 0x80001001)
  sd t1, 0(s0)
  CHK(2, 6, 0x80001001)
  li s0, 0x80100000
  ld t1, 0(s0)
  CHK(3, 5, 0x80100000)
  sd t1, 0(s0)
  CHK(4, 7, 0x80100000)
  li s0, 0x80001003
  lw t1, 0(s0)
  CHK(5, 4, 0x80001003)
  sw t1, 0(s0)
  CHK(6, 6, 0x80001003)
  lh t1, 0(s0)
  CHK(7, 4, 0x80001003)
  li s0, 0x80100000
  jalr ra, 0(s0)
  CHK(8, 1, 0x80100000)
  ecall
  CHK(9, 11, 0x73)
  li s0, 0x80001001
  li t0, 0x6000
  csrs mstatus, t0
  amoadd.w t1, t1, (s0)
  CHK(10, 6, 0x80001001)
  fld ft0, 0(s0)
  CHK(12, 4, 0x80001001)
  fsd ft0, 0(s0)
  CHK(13, 6, 0x80001001)
  PASS
