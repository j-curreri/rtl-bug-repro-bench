#include "test.h"
#include "hyp.h"

/*
 * Bug: in core/cvxif_fu.sv the illegal-instruction exception raised when a
 * CVXIF-offloaded instruction is rejected by the coprocessor is tagged with
 *     x_exception_o.gva = CVA6Cfg.RVH ? v_i : 1'b0;
 * For an illegal instruction, mtval holds the *instruction*, not a virtual
 * address, so mstatus.GVA / hstatus.GVA must be 0 (no guest virtual address
 * caused the trap).  The decoder's own illegal-instruction path leaves gva=0,
 * so the CVXIF path (gva=v_i) is the deviation.
 *
 * Test: run in VS-mode (v_i = 1) and execute a reserved custom-0 instruction.
 * The core offloads it to the CVXIF coprocessor, the coprocessor rejects it
 * (it only knows its custom-3 / MADD.. encodings), and an illegal-instruction
 * exception is taken.  MPP=M, so the trap returns to M-mode and mstatus.GVA is
 * written from the FU's gva.  A spec-conformant core leaves GVA=0; the buggy
 * core sets GVA=1 (because we were in VS-mode).
 */

/* reserved custom-0 R-type: opcode=0x0b rd=1 rs1=1 rs2=1 funct3=0 funct7=0 */
#define ILLG 0x10808b

  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* enter VS-mode; after the mret, MPP=M so the trap returns to M-mode */
  ENTER_VS(vs_code)
  FAIL(50)               /* unreachable */

vs_code:
  .word ILLG             /* illegal -> offloaded to CVXIF -> rejected -> trap */
  FAIL(51)               /* unreachable (must have trapped) */

/* M-mode trap handler (overrides the weak default in crt.S). */
  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li   t1, 2             /* illegal instruction */
  bne  t0, t1, bad_cause
  csrr t0, mstatus
  li   t1, MSTATUS_GVA   /* bit 38 */
  and  t0, t0, t1
  bnez t0, bad_gva       /* GVA must be 0 for an illegal instruction */
  PASS
bad_cause:
  FAIL(3)
bad_gva:
  FAIL(2)
