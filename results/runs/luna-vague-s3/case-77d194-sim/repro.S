#include "hyp.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  li t0, (1 << 20)          /* mstatus.TVM */
  csrs mstatus, t0
  ENTER_MODE(1, hs_attempt_hgatp_write)

  .align 2
hs_attempt_hgatp_write:
  /* TVM restricts satp/vsatp, but an HS-mode hgatp write remains legal. */
  li t0, 0
  csrw hgatp, t0
  PASS

  .globl trap_handler
  .align 2
trap_handler:
  FAIL(2)
