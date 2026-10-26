#include "test.h"

/* Bug: with S-mode absent, U-mode access to the counters is gated by scounteren as
 * well as mcounteren. Per the privileged spec, mcounteren alone governs U-mode access
 * when S-mode is not implemented. Here M-mode enables all counters and drops to U-mode,
 * where reading `cycle` must succeed; the buggy core raises an illegal-instruction trap. */

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  li t0, -1
  csrw mcounteren, t0
  ENTER_MODE(0, user_code)

user_code:
  rdcycle t0
  ecall

  .globl trap_handler
  .align 2
trap_handler:
  csrr t1, mcause
  li t2, 8  # ecall from U-mode
  bne t1, t2, 1f
  PASS
1:
  FAIL(1)
