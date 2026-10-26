#include "test.h"

/* Spec (priv 3.1.16): for causes other than the listed address/breakpoint-hardware
 * causes and illegal instruction, mtval is set to zero. ECALL from U/S/M and EBREAK
 * therefore must write 0 to mtval. This core writes the instruction encoding instead.
 * The handler checks mtval on every trap and counts traps in s1. */

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  li s1, 0                 /* trap counter */

  /* M-mode ECALL */
  ecall

  /* EBREAK */
  ebreak

  /* S-mode ECALL (no delegation, so it traps to M) */
  ENTER_MODE(1, s_part)
s_part:
  ecall
  /* after the S-mode ecall the handler returns to M-mode here */

  /* U-mode ECALL (no delegation, so it traps to M) */
  ENTER_MODE(0, u_part)
u_part:
  ecall
  /* after the U-mode ecall the handler returns to M-mode here */

  li t0, 4
  bne s1, t0, 1f
  PASS
1:
  FAIL(2)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mtval
  bnez t0, 2f              /* mtval must be zero for these causes */
  addi s1, s1, 1
  csrr t0, mepc
  addi t0, t0, 4           /* ecall and ebreak are 4-byte instructions */
  csrw mepc, t0
  li t0, (3 << 11)
  csrs mstatus, t0         /* return to M-mode */
  mret
2:
  FAIL(1)
