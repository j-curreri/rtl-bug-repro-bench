#include "test.h"
#include "hyp.h"

/*
 * Reproducer: illegal instruction executed in VS-mode with the CV-X-IF
 * coprocessor interface enabled causes a trap into M-mode that reports
 * mstatus.GVA = 1.  For an illegal-instruction trap, mtval holds the
 * instruction (not a guest virtual address), so GVA must be 0.
 *
 * Root cause (core/cvxif_fu.sv): when the coprocessor rejects an offloaded
 * instruction, the CVXIF functional unit raises an illegal-instruction
 * exception with  gva = v_i.  In VS-mode v_i = 1, so mstatus.GVA becomes 1.
 *
 * How this test reaches that code path:
 *   1. With CvxifEn=1, any instruction the main decoder marks illegal is
 *      offloaded to the coprocessor (CVXIF) functional unit instead of
 *      raising the exception in the decoder (core/decoder.sv).
 *   2. The coprocessor rejects an instruction it does not recognize
 *      (issue ready=1, accept=0 -> transaction rejected), so cvxif_fu raises
 *      the illegal-instruction exception with gva = v_i.
 *   3. A reserved RISC-V opcode is illegal in the main decoder and is never
 *      claimed by any coprocessor, so it is offloaded and then rejected.
 *   4. The resulting synchronous trap from VS-mode is taken into M-mode
 *      (no delegation), and mstatus.GVA captures the (buggy) gva value.
 *
 * Expected:
 *   - correct core: trap cause = illegal instruction, mstatus.GVA == 0 -> PASS
 *   - buggy core:   trap cause = illegal instruction, mstatus.GVA == 1 -> FAIL(1)
 */

  .text
  .globl test_main

test_main:
  /* Grant S/VS-mode access to all memory so VS-mode code can fetch/execute. */
  PMP_ALLOW_ALL

  /* Keep M-mode interrupts off so nothing else traps during the test. */
  csrci mstatus, 8            /* clear MIE */

  /* mret into VS-mode (V=1, priv=S) at vs_illegal; no return. */
  ENTER_VS(vs_illegal)

/* ---- now running in VS-mode ---- */

vs_illegal:
  .align 2
  /* A reserved opcode (0x6b): illegal in the main decoder, offloaded to the
   * coprocessor, and rejected there -> illegal-instruction trap into M-mode. */
  .word 0x0000006b
  /* Reached only if the coprocessor unexpectedly accepted the instruction.
   * A reserved opcode is never claimed, so this should never happen. */
  FAIL(2)

/* ---- M-mode trap handler (mtvec) ---- */

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li   t1, 2                   /* riscv::ILLEGAL_INSTR */
  bne  t0, t1, bad_cause

  csrr t0, mstatus
  /* Confirm the trap came from a virtualized (VS) context: mstatus.MPV == 1. */
  srli t1, t0, 39              /* MSTATUS_MPV */
  andi t1, t1, 1
  beqz t1, bad_mpv

  /* The check under test: mstatus.GVA must be 0 for an illegal-instruction
   * trap, regardless of whether we came from VS-mode. */
  srli t1, t0, 38              /* MSTATUS_GVA */
  andi t1, t1, 1
  beqz t1, gva_ok

  FAIL(1)                      /* GVA == 1 : the reported bug */

gva_ok:
  PASS

bad_mpv:
  FAIL(4)                      /* did not trap out of a virtualized context */
bad_cause:
  FAIL(3)                      /* unexpected trap cause */
