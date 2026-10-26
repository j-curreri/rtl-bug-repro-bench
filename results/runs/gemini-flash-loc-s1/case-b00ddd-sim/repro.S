#include "hyp.h"

.globl test_main
test_main:
  // Allow full memory access across privilege modes
  PMP_ALLOW_ALL

  // Register trap handler
  la t0, trap_handler
  csrw mtvec, t0

  // Ensure GVA is clear prior to entering VS-mode
  li t0, MSTATUS_GVA
  csrc mstatus, t0

  // Transition to VS-mode at guest_code
  ENTER_VS(guest_code)

guest_code:
  // 32-bit all-zeros instruction word is guaranteed to be illegal in RISC-V.
  // CVXIF receives illegal instructions and cvxif_fu handles the illegal
  // instruction exception.
  .word 0x00000000

  // If no trap occurred, fail
  FAIL(1)

.globl trap_handler
.align 2
trap_handler:
  // Check that mcause is illegal instruction (cause 2)
  csrr t0, mcause
  li t1, 2
  bne t0, t1, unexpected_trap

  // Check that trap occurred from VS-mode (mstatus.MPV == 1)
  csrr t0, mstatus
  li t1, MSTATUS_MPV
  and t2, t0, t1
  beqz t2, unexpected_trap

  // According to the RISC-V Hypervisor extension specification:
  // "The GVA (Guest Virtual Address) bit is written by the implementation whenever
  // a trap is taken into M-mode. For traps that write a guest virtual address to mtval,
  // GVA is set to 1. For other traps, GVA is set to 0."
  //
  // An illegal instruction does not write a guest virtual address to mtval
  // (mtval contains the instruction word or 0). Thus, mstatus.GVA must be 0
  // on any specification-compliant core.
  //
  // In the buggy core, cvxif_fu.sv sets `x_exception_o.gva = CVA6Cfg.RVH ? v_i : 1'b0;`
  // which causes mstatus.GVA to become 1 on an illegal instruction in VS-mode.
  li t1, MSTATUS_GVA
  and t2, t0, t1
  bnez t2, buggy_core

  // Specification compliant: GVA is 0
  PASS

buggy_core:
  FAIL(2)

unexpected_trap:
  FAIL(127)
