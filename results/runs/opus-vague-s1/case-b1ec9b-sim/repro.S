#include "test.h"

/* Bug: MRET to a privilege below M must clear mstatus.MPRV, but the core
 * only clears it when the H extension is enabled. */

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  li t0, (1 << 17)          /* MPRV = 1 */
  csrs mstatus, t0
  ENTER_MODE(1, s_code)     /* MPP = S; MRET must clear MPRV */

s_code:
  ecall                     /* back to M-mode */
  FAIL(2)

  .globl trap_handler
  .align 4
trap_handler:
  csrr t0, mcause
  li t1, 9                  /* ecall from S-mode */
  bne t0, t1, 1f
  csrr t0, mstatus
  li t1, (1 << 17)
  and t0, t0, t1
  bnez t0, 2f
  PASS
1:
  FAIL(3)
2:
  FAIL(1)
