#include "harness/test.h"

.globl test_main
test_main:
  PMP_ALLOW_ALL

  # Ensure MPV = 0 (return to HS-mode, not VS-mode)
  li t0, 1
  slli t0, t0, 39
  csrc mstatus, t0

  # Set mstatus.TVM = 1 (bit 20)
  li t0, (1 << 20)
  csrs mstatus, t0

  # Enter HS-mode (MPP = 1, privilege level S, V = 0)
  ENTER_MODE(1, hs_code)

hs_code:
  # In HS-mode with mstatus.TVM = 1:
  # The RISC-V privileged specification dictates that mstatus.TVM intercepts
  # supervisor virtual-memory operations (satp, SFENCE.VMA, SINVAL.VMA).
  # It does NOT intercept hypervisor address-translation CSRs such as hgatp.
  #
  # On a correct core: csrw hgatp does not trap and execution reaches PASS.
  # On this buggy core: writes to hgatp are incorrectly intercepted by TVM,
  # causing an unexpected illegal-instruction trap to M-mode.
  csrw hgatp, zero

  # Correct core reaches PASS
  PASS

  .align 2
.globl trap_handler
trap_handler:
  # Unexpected trap on buggy core
  FAIL(1)
