#include "test.h"

  .option norvc
  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* 1: ecall from M-mode: mtval must be 0 */
  li s1, -1
  ecall
  bnez s1, f1
  /* 2: ebreak from M-mode: mtval must be 0 or the address of the ebreak */
  li s1, -1
ebrk:
  ebreak
  beqz s1, 1f
  la t0, ebrk
  bne s1, t0, f2
1:
  /* 3: ecall from U-mode: mtval must be 0 */
  li s1, -1
  ENTER_MODE(0, umode)
umode:
  ecall
  bnez s1, f3
  /* 4: ecall from S-mode (handler returns to M) */
  li s1, -1
  ENTER_MODE(1, smode)
smode:
  ecall
  bnez s1, f4
  PASS
f1: FAIL(1)
f2: FAIL(2)
f3: FAIL(3)
f4: FAIL(4)

  .globl trap_handler
  .align 2
trap_handler:
  csrr s1, mtval
  csrr t0, mcause
  li t1, 3
  bltu t0, t1, bad
  li t1, 11
  bgtu t0, t1, bad
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  /* return to M-mode so later tests run in M */
  li t0, (3 << 11)
  csrs mstatus, t0
  mret
bad:
  FAIL(100)
