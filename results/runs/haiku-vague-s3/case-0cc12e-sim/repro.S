#include "test.h"

/* Spec (priv 3.1.16): mtval is zero after an ECALL trap ("other traps set mtval to zero").
 * The buggy core writes the ecall instruction bits (0x73) into mtval. */
  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  li s0, 0
  ecall
  /* Not reached: the handler PASSes or FAILs. */
  FAIL(2)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 11               /* ENV_CALL_MMODE */
  bne t0, t1, 1f
  csrr t2, mtval
  bnez t2, 2f             /* mtval must be 0 for ecall */
  PASS
1:
  FAIL(3)                 /* unexpected cause */
2:
  FAIL(1)                 /* mtval != 0 for ecall */
