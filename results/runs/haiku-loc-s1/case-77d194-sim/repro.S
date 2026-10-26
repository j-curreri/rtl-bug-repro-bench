#include "test.h"

/* Counter access from U-mode: with mcounteren.CY=1 and scounteren.CY=0, a read of
 * the cycle CSR must raise an illegal-instruction exception (in U-mode with V=0 the
 * access needs both mcounteren and scounteren). The privilege check in
 * csr_regfile.sv (the Zicntr and Zihpm blocks) computes ~mcounteren & ~scounteren
 * where ~mcounteren | ~scounteren is needed, so the read is allowed. */

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  li t0, 1                # mcounteren.CY = 1
  csrw mcounteren, t0
  csrw scounteren, zero   # scounteren.CY = 0
  ENTER_MODE(0, user_code)

user_code:
  csrr a0, cycle          # correct core: illegal instruction trap
  ecall                   # only reached on the buggy core; traps with cause 8

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 2                # illegal instruction
  bne t0, t1, 1f
  PASS
1:
  FAIL(1)
