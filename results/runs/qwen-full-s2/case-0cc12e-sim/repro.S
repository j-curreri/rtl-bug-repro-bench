#include "test.h"
/*
 * Bug reproducer: wrong mtval after synchronous ENV_CALL / BREAKPOINT.
 *
 * The RISC-V privileged spec requires mtval (and stval/vstval) to be 0 for
 * environment-call (cause 8/9/11/12) and breakpoint (cause 3) exceptions;
 * there is no faulting address to record for them.
 *
 * This core instead writes the raw faulting instruction word into mtval for
 * these causes (the decoder stores the instruction in ex.tval and the trap
 * logic only zeroes it when ZERO_TVAL is set, which requires SPIKE_TANDEM).
 *
 * Strategy: run ecall/ebreak in M-mode, trap to our own handler, and require
 * mtval == 0 for both. A spec-compliant core ends with PASS; this core fails.
 */

  .section .text
  .globl test_main

test_main:
  la t0, trap_handler
  csrw mtvec, t0

  /* Test 1: ecall from M-mode -> mcause 11, mtval must be 0 */
  ecall
  FAIL(1)                 /* ecall did not trap */

  .align 2
trap_handler:
  csrr t0, mcause
  csrr t1, mtval
  li t2, 11               /* ENV_CALL_MMODE */
  beq t0, t2, chk_ecall
  li t2, 3                /* BREAKPOINT */
  beq t0, t2, chk_ebreak
  FAIL(50)                /* unexpected cause */

chk_ecall:
  bnez t1, fail_ecall     /* mtval must be 0 */
  la t3, t_ecall_done
  csrw mepc, t3
  mret

chk_ebreak:
  bnez t1, fail_ebreak    /* mtval must be 0 */
  la t3, t_ebreak_done
  csrw mepc, t3
  mret

fail_ecall:
  FAIL(20)                /* ecall: mtval != 0 */
fail_ebreak:
  FAIL(30)                /* ebreak: mtval != 0 */

t_ecall_done:
  /* Test 2: ebreak from M-mode -> mcause 3, mtval must be 0 */
  ebreak
  FAIL(2)                 /* ebreak did not trap */

t_ebreak_done:
  PASS
