#include "test.h"

/* Spec (privileged, counter access): a U-mode read of a counter CSR is legal only if
 * mcounteren[n] AND scounteren[n] are both set. Here mcounteren allows cycle but
 * scounteren does not, so `csrr a0, cycle` in U-mode must raise an illegal-instruction
 * exception at cyc_insn. */

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  li t0, 0x7                /* CY, TM, IR visible to S/U-mode */
  csrw mcounteren, t0
  csrw scounteren, zero     /* S-level gate closed */
  ENTER_MODE(0, cyc_insn)

  .align 2
cyc_insn:
  csrr a0, cycle            /* must trap: scounteren[0] == 0 */
  ecall                     /* reached only if the read did not trap */

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 2                  /* illegal instruction */
  bne t0, t1, 1f
  la t1, cyc_insn
  csrr t2, mepc
  bne t1, t2, 1f
  PASS
1:
  FAIL(1)
