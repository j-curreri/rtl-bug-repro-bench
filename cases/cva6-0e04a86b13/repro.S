/* ecall must report mtval = 0; ebreak must report mtval = address of the ebreak. */
#include "test.h"
  .text
  .globl test_main
test_main:
  li s0, 0
  li t0, 0x5a5a5a5a
  csrw mtval, t0
ecall_site:
  ecall
  li t0, 0x5a5a5a5a
  csrw mtval, t0
  .option push
  .option norvc
ebreak_site:
  ebreak
  .option pop
  PASS

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  csrr t1, mtval
  li t2, 11                    /* ecall from M-mode */
  beq t0, t2, on_ecall
  li t2, 3                     /* breakpoint */
  beq t0, t2, on_ebreak
  FAIL(1)
on_ecall:
  bnez t1, 2f
  j resume
on_ebreak:
  la t2, ebreak_site
  bne t1, t2, 3f
resume:
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret
2: FAIL(2)
3: FAIL(3)
