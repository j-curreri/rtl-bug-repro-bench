/*
 * Bug reproducer (CV-X-IF + hypervisor):
 *
 *   When an illegal instruction is executed in VS-mode on a core with the
 *   CV-X-IF coprocessor interface enabled, the trap into M-mode reports
 *   mstatus.GVA = 1. For an illegal-instruction trap mtval does not hold a
 *   guest virtual address, so mstatus.GVA must be 0.
 *
 * Mechanism in this core (CvxifEn = 1): the decoder routes *every* illegal
 * instruction to the CVXIF functional unit, where it is offloaded to the
 * coprocessor. The coprocessor rejects it (issue_resp.accept = 0), so the
 * core raises an illegal-instruction exception in the mode that was
 * executing. That exception is produced by cvxif_fu, which (in the buggy RTL)
 * sets the exception's gva field to the executing virtualization bit v_i.
 * Taking the trap into M-mode copies that into mstatus.GVA.
 *
 * Strategy:
 *   1. Grant S/VS-mode access to all memory (PMP).
 *   2. mret into VS-mode (V = 1, S-privilege).
 *   3. Execute an instruction that is illegal in this core. It is offloaded
 *      to CVXIF, rejected, and raises an illegal-instruction trap to M-mode.
 *   4. In the M-mode trap handler, read mstatus.GVA:
 *        GVA == 0  -> correct core  -> PASS
 *        GVA == 1  -> buggy core    -> FAIL
 *
 * The program ends with PASS on a correct core and with FAIL (code 1) on the
 * buggy core. Any unexpected trap fails with code 127.
 */
#include "hyp.h"

  .text
  .globl test_main
test_main:
  # Allow S/VS-mode to fetch and access all physical memory so the VS-mode
  # code below can run (bare address translation: VA == GPA == PA).
  PMP_ALLOW_ALL
  # mret into VS-mode (V = 1, S-privilege) at the vs_trap label.
  ENTER_VS(vs_trap)
  # We must not return from that mret; reaching here means the entry into
  # VS-mode did not trap (should never happen).
  FAIL(1)

  .align 2
vs_trap:
  # We are now executing in VS-mode (V = 1, S-privilege).
  # Execute a 32-bit instruction whose opcode (0x5B = custom-2) is not
  # recognised by the decoder -> illegal. With CvxifEn = 1 it is offloaded to
  # the CVXIF coprocessor, which rejects it, so this raises an
  # illegal-instruction exception while in VS-mode.
  .word 0x0000005B
  # If the illegal instruction did not trap, something is very wrong.
  FAIL(2)

  .align 2
  .globl trap_handler
trap_handler:
  # M-mode trap handler (mtvec -> here, set up by crt.S _start).
  csrr  t0, mcause
  li    t1, 2                 # cause = illegal instruction
  bne   t0, t1, unexpected    # not the expected trap -> fail

  csrr  t0, mstatus
  # Sanity check: confirm the trap originated from a virtualized (V = 1)
  # context, i.e. mstatus.MPV (bit 39) is set.
  srli  t1, t0, 39
  andi  t1, t1, 1
  beqz  t1, unexpected

  # The property under test: mstatus.GVA (bit 38) must be 0 for an
  # illegal-instruction trap (mtval holds the offending instruction, not a
  # guest virtual address). The buggy core sets it to v_i = 1 instead.
  srli  t1, t0, 38
  andi  t1, t1, 1
  beqz  t1, pass_ok           # GVA == 0: spec-compliant -> PASS
  FAIL(1)                     # GVA == 1: bug present -> FAIL
pass_ok:
  PASS
unexpected:
  FAIL(127)
