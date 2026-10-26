#include "test.h"

/* mcounteren.CY is set, so U-mode may read the cycle counter. There is no S-mode
 * in this configuration (RVS=0), so mcounteren alone controls U-mode access. The
 * buggy core also requires scounteren.CY, which does not exist here, and traps. */
  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  li t0, 1
  csrw mcounteren, t0
  ENTER_MODE(0, user_code)

user_code:
  csrr t1, cycle
  ecall

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 8
  bne t0, t1, 1f
  PASS
1:
  FAIL(1)
