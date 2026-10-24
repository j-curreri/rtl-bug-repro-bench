#include "test.h"

/* Spec: ecall -> mtval = 0; ebreak -> mtval = 0 or the faulting PC.
 * The trap handler records mcause/mtval/mepc in s2/s3/s4 and resumes at s5. */

  .text
  .globl trap_handler
  .align 2
trap_handler:
  csrr s2, mcause
  csrr s3, mtval
  csrr s4, mepc
  jr s5

  .globl test_main
test_main:
  csrw medeleg, zero
  csrw mideleg, zero
  PMP_ALLOW_ALL

  /* 1: ecall from M-mode */
  la s5, 1f
  li s3, -1
  .option push
  .option norvc
m_ecall:
  ecall
  .option pop
1:
  li t0, 11
  bne s2, t0, fail1
  bnez s3, fail1

  /* 2: ebreak (32-bit) from M-mode */
  la s5, 1f
  li s3, -1
  .option push
  .option norvc
m_ebreak:
  ebreak
  .option pop
1:
  li t0, 3
  bne s2, t0, fail2
  beqz s3, 2f
  la t0, m_ebreak
  bne s3, t0, fail2
2:

  /* 3: c.ebreak from M-mode */
  la s5, 1f
  li s3, -1
m_cebreak:
  c.ebreak
1:
  li t0, 3
  bne s2, t0, fail3
  beqz s3, 2f
  la t0, m_cebreak
  bne s3, t0, fail3
2:

  /* 4: ecall from S-mode */
  la s5, 1f
  li s3, -1
  ENTER_MODE(1, s_code)
1:
  li t0, 9
  bne s2, t0, fail4
  bnez s3, fail4

  /* 5: ecall from U-mode */
  la s5, 1f
  li s3, -1
  ENTER_MODE(0, u_code)
1:
  li t0, 8
  bne s2, t0, fail5
  bnez s3, fail5

  /* 6: ebreak from U-mode */
  la s5, 1f
  li s3, -1
  ENTER_MODE(0, u_ebreak)
1:
  li t0, 3
  bne s2, t0, fail6
  beqz s3, 2f
  la t0, u_ebreak
  bne s3, t0, fail6
2:
  PASS

fail1: FAIL(1)
fail2: FAIL(2)
fail3: FAIL(3)
fail4: FAIL(4)
fail5: FAIL(5)
fail6: FAIL(6)

  .option push
  .option norvc
  .align 2
s_code:
  ecall
  j s_code
  .align 2
u_code:
  ecall
  j u_code
  .align 2
u_ebreak:
  ebreak
  j u_ebreak
  .option pop
