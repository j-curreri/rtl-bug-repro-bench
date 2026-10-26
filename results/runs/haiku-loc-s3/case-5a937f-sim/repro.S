/* Reproducer: in VU-mode (V=1, U) with mcounteren[0]=0, reading the cycle CSR must raise
 * an illegal-instruction exception (RISC-V priv spec, counter access rules; H-ext rules
 * for V=1 defer to mcounteren first). The buggy privilege check lets the read succeed when
 * scounteren and hcounteren are also clear. */
#include "hyp.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  csrw mcounteren, zero
  csrw scounteren, zero
  csrw hcounteren, zero
  /* enter VU-mode with virtualization enabled (MPV=1, MPP=U) */
  li t0, MSTATUS_MPV
  csrs mstatus, t0
  ENTER_MODE(0, vu_code)

vu_code:
  csrr t0, cycle          /* must trap: mcounteren[0] = 0 */
  li a0, 0x77
  ecall                   /* reached only if the read did not trap */

  .globl trap_handler
  .align 2
trap_handler:
  csrr t6, mcause
  li t5, 2                /* illegal instruction */
  bne t6, t5, 1f
  PASS
1:
  FAIL(1)
