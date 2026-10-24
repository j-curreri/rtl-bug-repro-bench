#include "test.h"
/* ECALL: mtval must be 0. EBREAK: mtval must be 0 or the PC of the ebreak. */
  .text
  .globl test_main
test_main:
  la t0, trap_handler
  csrw mtvec, t0
  li s1, 0                /* trap counter */

  csrwi mtval, 0
  li s2, 1
1: ecall
  la t0, 1b
  bne s3, t0, fail_epc
  bnez s4, fail_tval_ecall

  li t0, -1
  csrw mtval, t0
  li s2, 2
.option push
.option norvc
2: ebreak
.option pop
  la t0, 2b
  bne s3, t0, fail_epc
  beqz s4, 3f
  bne s4, t0, fail_tval_ebreak
3:
  li t0, -1
  csrw mtval, t0
  li s2, 3
4: c.ebreak
  la t0, 4b
  bne s3, t0, fail_epc
  beqz s4, 5f
  bne s4, t0, fail_tval_cebreak
5:
  li t0, 3
  bne s1, t0, fail_count
  PASS
fail_epc:         FAIL(2)
fail_tval_ecall:  FAIL(3)
fail_tval_ebreak: FAIL(4)
fail_tval_cebreak: FAIL(5)
fail_count:       FAIL(6)

  .align 2
  .globl trap_handler
trap_handler:
  csrr s3, mepc
  csrr s4, mtval
  csrr t1, mcause
  li t2, 11
  li t0, 1
  beq s2, t0, 6f
  li t2, 3
6:
  bne t1, t2, bad_cause
  addi s1, s1, 1
  /* advance mepc past the trapping instruction (2 or 4 bytes) */
  lhu t0, 0(s3)
  andi t0, t0, 3
  li t1, 3
  addi s3, s3, 2
  bne t0, t1, 7f
  addi s3, s3, 2
7:
  csrw mepc, s3
  addi s3, s3, -2
  bne t0, t1, 8f
  addi s3, s3, -2
8:
  mret
bad_cause: FAIL(7)
