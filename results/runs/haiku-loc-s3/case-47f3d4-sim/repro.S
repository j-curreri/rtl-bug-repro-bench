#include "test.h"

/* Bug: with no S-mode (cv64a6_imafdc_mu has RVS=0), U-mode counter access is gated by
 * scounteren as well as mcounteren. scounteren does not exist here and is never reset, so
 * U-mode rdcycle traps even though mcounteren.CY is set. Per the privileged spec, when S-mode
 * is not implemented, mcounteren alone decides U-mode access, so the read must succeed.
 *
 * Expected: rdcycle in U-mode returns without a trap, the ecall reaches the handler with
 * cause 8, and the program passes. The buggy core traps on rdcycle with cause 2. */

  .section .text.init
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  li t0, 0x1              /* mcounteren.CY = 1 */
  csrw mcounteren, t0
  ENTER_MODE(0, u_code)

u_code:
  rdcycle a0              /* must not trap: only mcounteren governs U-mode without S-mode */
  ecall                   /* return to M-mode through the handler, cause 8 */

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 8                /* environment call from U-mode is the only expected trap */
  beq t0, t1, 1f
  FAIL(2)
1: PASS
