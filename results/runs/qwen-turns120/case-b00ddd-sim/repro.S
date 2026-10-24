#include "test.h"
#include "hyp.h"
/*
 * Reproducer for: "illegal-instruction trap from VS-mode reports mstatus.GVA=1
 * when the CV-X-IF coprocessor interface is enabled."
 *
 * With CvxifEn, any instruction that is illegal in the main decoder is
 * offloaded to the CVXIF coprocessor (decoder.sv sets fu=CVXIF). If the
 * coprocessor rejects the instruction, the core raises an illegal-instruction
 * exception (cause 2). cvxif_fu.sv sets that exception's `gva` to the current
 * virtualization bit (v_i) instead of 0. So when the faulting instruction is
 * executed in VS-mode, the trap into M-mode writes mstatus.GVA = 1, although
 * for an illegal-instruction trap mtval holds the instruction, not a guest
 * virtual address - the spec requires mstatus.GVA = 0.
 *
 * Plan:
 *   - Enter VS-mode (priv=S, v=1).
 *   - Execute an instruction that is illegal in the main decoder but not
 *     supported by the coprocessor, so it is offloaded and rejected.
 *   - The resulting illegal-instruction trap lands in M-mode (no delegation).
 *   - In the M-mode handler, check mstatus.GVA:
 *       GVA==0 -> correct behaviour -> PASS
 *       GVA==1 -> the bug -> FAIL
 */

  .section .text
  .globl test_main

test_main:
  /* M-mode setup */
  PMP_ALLOW_ALL

  /* No trap delegation: the illegal-instruction trap goes straight to M-mode,
     so the hypervisor exception fields land in mstatus (not hstatus). */
  csrw medeleg, zero
  csrw mideleg, zero

  /* Disable G-stage and VS-stage translation so that instruction fetch in
     VS-mode uses physical addresses and cannot fault. */
  csrw hgatp, zero
  csrw vsatp, zero

  /* Put mstatus.GVA in a known state. */
  li t0, MSTATUS_GVA
  csrc mstatus, t0

  /* Enter VS-mode (priv=S, v=1). */
  ENTER_VS(vs_entry)

vs_entry:
  /* Running in VS-mode. Execute an instruction that is illegal in the main
     decoder (OpcodeCustom2 = 1011011) and therefore offloaded to the CVXIF
     coprocessor, which rejects it -> illegal-instruction exception. */
marker:
  .word 0x0000005B
  /* Reaching here would mean the instruction was not illegal - not expected. */
  li a0, (5 << 1) | 1
  j _halt

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  csrr t1, mepc
  csrr t2, mstatus
  /* Expect an illegal-instruction trap (cause 2) at the marker. */
  li t3, 2
  bne t0, t3, unexpected_trap
  la t3, marker
  bne t1, t3, unexpected_trap
  /* Check mstatus.GVA (bit 38). */
  srli t2, t2, 38
  andi t2, t2, 1
  beq t2, zero, repro_pass
  /* GVA==1 on an illegal-instruction trap: this is the bug. */
  FAIL(3)
repro_pass:
  PASS
unexpected_trap:
  FAIL(127)
