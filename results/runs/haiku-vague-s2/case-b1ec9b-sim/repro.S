#include "test.h"

/* Bug: MRET does not clear mstatus.MPRV when returning to a mode less privileged than M.
 * Per the privileged spec, MRET with MPP != M must set MPRV = 0. This core only does so
 * when the H extension is enabled, so with H disabled MPRV survives the return.
 *
 * Flow: set MPRV, MRET to U-mode, ecall back to M-mode, and check MPRV in the trap handler.
 * Reading mstatus needs no memory access, so the check is independent of MPRV's effect on
 * loads and stores. */

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  li t0, (1 << 17)              /* mstatus.MPRV */
  csrs mstatus, t0
  ENTER_MODE(0, u_code)         /* MRET to U-mode, MPP = U */

u_code:
  ecall                         /* U-mode ecall traps to M-mode trap_handler */
  FAIL(2)                       /* not reached */

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mstatus
  srli t0, t0, 17
  andi t0, t0, 1
  bnez t0, 1f                   /* MPRV still set after MRET to U: bug */
  PASS
1:
  FAIL(1)
