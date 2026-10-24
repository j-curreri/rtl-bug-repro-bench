/* Bug reproducer: an illegal instruction executed in VS-mode reports
 * mstatus.GVA = 1 on a trap into M-mode, even though for an
 * illegal-instruction trap mtval holds the faulting instruction (not a
 * guest virtual address), so mstatus.GVA must be 0.
 *
 * Root cause (CV-X-Interface path): with CvxifEn, an illegal instruction is
 * offloaded to the coprocessor interface instead of being trapped by the
 * decoder. When the coprocessor rejects the transaction, the exception
 * raised by cvxif_fu carries gva = v_i (the virtualization-mode flag) rather
 * than 0, so in VS-mode the trap into M-mode wrongly sets mstatus.GVA = 1.
 * (The decoder path correctly leaves gva = 0 for illegal instructions.)
 *
 * - On a correct core this program ends with PASS.
 * - On the buggy core the illegal-instruction trap reports GVA = 1, so the
 *   program ends with FAIL(2).
 */
#include "test.h"
#include "hyp.h"

  .globl test_main
  .globl trap_handler
test_main:
  /* Grant S/U-mode access to all memory so code can run in virtual
   * supervisor mode. */
  PMP_ALLOW_ALL

  /* M-mode trap vector -> our handler. */
  la   t0, trap_handler
  csrw mtvec, t0

  /* Enter virtual supervisor mode: mret with MPP=S and mstatus.MPV=1.
   * Afterwards the hart runs at privilege S with the virtualization flag
   * (v) asserted. No G-stage/VS-stage tables are set up (both satp registers
   * stay in Bare mode), so virtual addresses are used directly as physical. */
  ENTER_VS(vs_main)

  /* Not reached. */
  j _halt

  .align 2
vs_main:
  /* Now in VS-mode (privilege S, v = 1). Execute a reserved 32-bit
   * instruction: opcode 0x6B (Rsrvd2), all other fields zero. The decoder
   * marks it illegal and, with the CVXIF interface enabled, offloads it to
   * the coprocessor, which rejects it, raising an illegal-instruction
   * exception that traps into M-mode. */
  .word 0x0000006b

  /* Not reached. */
  j _halt

  .align 2
trap_handler:
  /* Trap taken into M-mode. Inspect the trap context. */
  csrr t0, mstatus
  csrr t1, mcause

  /* 1) This must be an illegal-instruction exception (mcause == 2). */
  li   t2, 2
  bne  t1, t2, fail_not_illegal

  /* 2) We must have trapped out of virtualization (mstatus.MPV == 1),
   *    confirming the fault occurred in VS-mode. */
  li   t2, MSTATUS_MPV
  and  t3, t0, t2
  beqz t3, fail_not_vs

  /* 3) For an illegal-instruction trap, mtval holds the instruction, not a
   *    guest virtual address, so mstatus.GVA must be 0. If it is set, the
   *    CVXIF path mis-reports GVA (the bug under test). */
  li   t2, MSTATUS_GVA
  and  t3, t0, t2
  bnez t3, fail_gva

  PASS

fail_not_illegal:
  FAIL(1)

fail_not_vs:
  FAIL(3)

fail_gva:
  FAIL(2)
