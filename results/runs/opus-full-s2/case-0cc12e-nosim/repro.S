#include "test.h"

/* Spec: mtval must be 0 for ECALL; for EBREAK it is 0 or the PC of the instruction.
 * Handler records mcause/mtval/mepc in s1/s2/s3 and resumes in M-mode at s4. */

  .text
  .globl trap_handler
  .align 4
trap_handler:
  csrr s1, mcause
  csrr s2, mtval
  csrr s3, mepc
  li t0, (3 << 11)
  csrs mstatus, t0
  csrw mepc, s4
  mret

#define CHECK_ECALL(cause, n) \
  li t0, cause;  bne s1, t0, fail_##n; \
  bnez s2, fail_##n

#define CHECK_EBREAK(n) \
  li t0, 3;  bne s1, t0, fail_##n; \
  beqz s2, 1f; bne s2, s3, fail_##n; 1:

  .globl test_main
test_main:
  PMP_ALLOW_ALL
  .option push
  .option norvc

  /* 1: ecall from M */
  la s4, 1f
  li s2, 0x55
  ecall
1:
  CHECK_ECALL(11, 1)

  /* 2: ebreak from M (32-bit) */
  la s4, 1f
  li s2, 0x55
  ebreak
1:
  CHECK_EBREAK(2)
  .option pop

  /* 3: c.ebreak from M */
  la s4, 1f
  li s2, 0x55
  c.ebreak
1:
  CHECK_EBREAK(3)

  .option push
  .option norvc
  /* 4: ecall from S */
  la s4, 1f
  li s2, 0x55
  ENTER_MODE(1, s_ecall)
1:
  CHECK_ECALL(9, 4)

  /* 5: ecall from U */
  la s4, 1f
  li s2, 0x55
  ENTER_MODE(0, u_ecall)
1:
  CHECK_ECALL(8, 5)

  /* 6: ebreak from U */
  la s4, 1f
  li s2, 0x55
  ENTER_MODE(0, u_ebreak)
1:
  CHECK_EBREAK(6)

  PASS

s_ecall:
  ecall
u_ecall:
  ecall
u_ebreak:
  ebreak
  .option pop

fail_1: FAIL(1)
fail_2: FAIL(2)
fail_3: FAIL(3)
fail_4: FAIL(4)
fail_5: FAIL(5)
fail_6: FAIL(6)
