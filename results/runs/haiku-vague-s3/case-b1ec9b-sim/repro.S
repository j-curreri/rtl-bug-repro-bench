#include "test.h"

/* MRET to a less-privileged mode must clear mstatus.MPRV (Privileged spec: MRET
 * clears MPRV when MPP != M). Here MPRV=1 and MPP=U, so after mret into U-mode
 * MPRV must read back as 0. U-mode then ecalls back to M-mode, which checks it. */

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  li t0, (1 << 17)            /* mstatus.MPRV */
  csrs mstatus, t0
  ENTER_MODE(0, user_code)    /* MPP = U, mret */

user_code:
  ecall                       /* U-mode ecall -> M-mode trap_handler */
  FAIL(3)                     /* not reached */

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 8                    /* environment call from U-mode */
  bne t0, t1, 1f
  csrr t0, mstatus
  li t1, (1 << 17)
  and t0, t0, t1
  bnez t0, 2f                 /* MPRV still set after MRET -> bug */
  PASS
1:
  FAIL(2)                     /* unexpected trap */
2:
  FAIL(1)                     /* MRET left MPRV set */
