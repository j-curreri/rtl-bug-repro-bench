#include "test.h"

/*
 * Reproducer for CVA6 bug in core/csr_regfile.sv:
 *
 * According to the RISC-V Privileged Specification:
 * "An MRET or SRET instruction that changes the privilege mode to a mode
 *  less privileged than M also sets MPRV=0."
 *
 * In core/csr_regfile.sv (lines 2418 and 2438), the logic clearing mstatus.MPRV
 * upon MRET and SRET was placed inside `if (CVA6Cfg.RVH) begin ... end`.
 * On cores where the Hypervisor extension (RVH) is disabled (such as cv64a6_imafdc_sv39),
 * mret does not clear mstatus.MPRV when transitioning from M-mode to S-mode or U-mode.
 *
 * On a compliant core:
 *   mret into S-mode clears mstatus.MPRV to 0. When S-mode traps back to M-mode,
 *   mstatus.MPRV is 0, so the test finishes with PASS.
 *
 * On this buggy core:
 *   mstatus.MPRV remains 1 after mret into S-mode, so the test finishes with FAIL(2).
 */

  .globl test_main
test_main:
  /* Grant S/U-mode access to all memory via PMP entry 0 */
  PMP_ALLOW_ALL

  /* Install M-mode trap handler */
  la t0, trap_handler
  csrw mtvec, t0

  /* Set mstatus.MPRV = 1 (bit 17) */
  li t0, (1 << 17)
  csrs mstatus, t0

  /* Verify mstatus.MPRV was successfully set in M-mode */
  csrr t0, mstatus
  li t1, (1 << 17)
  and t2, t0, t1
  beqz t2, fail_init

  /* Transition from M-mode to S-mode using mret via ENTER_MODE helper */
  ENTER_MODE(1, s_mode_entry)

s_mode_entry:
  /* Now executing in S-mode. Trap back to M-mode via ecall */
  ecall

  .align 2
  .globl trap_handler
trap_handler:
  /* Trap should be environment call from S-mode (mcause = 9) */
  csrr t0, mcause
  li t1, 9
  bne t0, t1, fail_cause

  /* Check mstatus.MPRV (bit 17) */
  csrr t0, mstatus
  li t1, (1 << 17)
  and t2, t0, t1
  /* If MPRV is still set (1), mret failed to clear MPRV as required by spec */
  bnez t2, fail_mprv_still_set

  PASS

fail_init:
  FAIL(1)

fail_mprv_still_set:
  FAIL(2)

fail_cause:
  FAIL(3)
