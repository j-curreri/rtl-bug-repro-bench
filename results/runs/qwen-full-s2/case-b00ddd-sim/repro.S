/* Bug reproducer: mstatus.GVA must be 0 on an illegal-instruction trap taken
 * from VS-mode. For cause=2, mtval holds the faulting instruction encoding,
 * not a guest virtual address, so the GVA bit of mstatus must be clear.
 *
 * With the CV-X-IF coprocessor interface enabled (CVA6ConfigCvxifEn = 1),
 * an instruction the core decodes as illegal is offloaded to the coprocessor
 * via the CVXIF issue interface. On rejection the coprocessor functional unit
 * raises the illegal-instruction exception with the gva field set to the
 * "virtualization mode" state (cvxif_fu.sv: x_exception_o.gva = v_i), so on
 * this core the trap into M-mode reports mstatus.GVA = 1; on a spec-conformant
 * core it reports 0.
 *
 * The test:
 *   1. set up a G-stage (Sv39x4) and a VS-stage (Sv39) page table identity-
 *      mapping the first 1 GiB (code and data live at 0x8000_0000);
 *   2. mret into VS-mode (MPP = S, mstatus.MPV = 1, hstatus.VT = 0 so that a
 *      plain illegal instruction traps to M-mode, not to HS-mode);
 *   3. execute the all-zero instruction 0x00000000: it is not part of the
 *      ISA and the coprocessor does not claim it, so the core takes an
 *      illegal-instruction exception (cause 2);
 *   4. in the M-mode trap handler verify mcause == 2, mstatus.MPV == 1
 *      (trap came from VS-mode) and finally mstatus.GVA:
 *      GVA = 1 -> FAIL(2) (bug), GVA = 0 -> PASS.
 */
#include "test.h"
#include "hyp.h"

HYP_TABLES

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* G-stage: identity-map the first 1 GiB (Sv39x4 top-level 1 GiB leaf). */
  GIGA_LEAF(g_root, 0, 0, G_RWX)
  HGATP_ON

  /* VS-stage: identity-map the first 1 GiB for the guest. */
  GIGA_LEAF(vs_root, 0, 0, VS_RWX)
  la t0, vs_root
  VSATP_ON(t0)

  /* Ensure a non-virtual illegal instruction in VS-mode traps to M-mode
   * (clear hstatus.VT explicitly). */
  li t1, (1 << 20)
  csrc hstatus, t1

  /* mret into VS-mode. */
  ENTER_VS(vs_main)

vs_main:
  /* Sanity check: we really are in VS-mode (vsatp in Sv39 mode). */
  csrr t0, vsatp
  srli t0, t0, 60
  li t1, 8
  bne t0, t1, fail_mode

  /* Execute an instruction that is neither in the ISA nor in the
   * coprocessor: 0x00000000 -> illegal-instruction exception (cause 2). */
  .word 0x00000000

  /* Reaching here means no trap was taken: wrong. */
  j fail_notrap

  .align 2
  .globl trap_handler
trap_handler:
  /* Expect the illegal-instruction exception (cause 2, no interrupt bit). */
  csrr t0, mcause
  li t1, 2
  bne t0, t1, fail_cause

  /* The trap must have been taken from VS-mode: mstatus.MPV must be 1. */
  csrr t0, mstatus
  srli t0, t0, 39
  beqz t0, fail_mpv

  /* The check itself: mstatus.GVA must be 0 for an illegal-instruction
   * trap - mtval holds the faulting instruction, not a guest virtual
   * address. */
  csrr t0, mstatus
  srli t0, t0, 38
  beqz t0, pass

  FAIL(2)
pass:
  PASS

fail_mode:
  FAIL(3)
fail_notrap:
  FAIL(4)
fail_cause:
  FAIL(5)
fail_mpv:
  FAIL(6)
