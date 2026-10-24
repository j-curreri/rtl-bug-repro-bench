/* repro.S - reproducer for "MRET does not update mstatus correctly in
 * some cases".
 *
 * Root cause in this core: the packed struct mstatus_rv_t in
 * core/include/riscv_pkg.sv places the SIE field at bit 1 and an extra
 * write-ignored wpri0 field at bit 0, while the RISC-V architecture has
 * SIE at bit 0 and write-reserved bits at 1-2. All internal logic
 * (sstatus read/write masks with SSTATUS_SIE = 0x2, the S-mode interrupt
 * enable path using mstatus_q.sie, trap entry / SRET / MRET update logic)
 * is self-consistent with that wrong layout, so the deviation is only
 * visible through the software mstatus/sstatus window:
 *   - writing mstatus.SIE (architectural bit 0, value 0x1) is discarded;
 *   - mstatus/sstatus bit 0 always reads 0;
 *   - the internal SIE can only be reached through bit 1 (architectural
 *     write-reserved).
 *
 * Software-visible consequence: set SIE=1, then MRET. The MRET updates
 * (priv <- MPP, MIE <- MPIE, MPIE <- 1, MPP <- U) happen correctly, but
 * the SIE bit does not survive: software reading mstatus (or sstatus
 * after an MRET into S-mode) sees SIE cleared. On a spec-conformant core
 * SIE is preserved and visible at bit 0.
 *
 * Test A (M-mode): mstatus = MPP=M | SIE(bit0) = 0x1801, MRET -> M-mode.
 *   mstatus low 12 bits must be MPIE(0x80) | SIE(0x1) = 0x081.
 *   This core: 0x080 (bit 0 was discarded on the write).
 * Test B (S-mode): mstatus = MPP=S | SIE(bit0) = 0x801, MRET -> S-mode.
 *   sstatus.SIE (bit 0) must be 1. This core: 0.
 *
 * Both tests pass on a spec-conformant core and the program ends with
 * PASS; on this core test A fails (FAIL(1)).
 */
#include "test.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* ---------- Test A: MRET must preserve mstatus.SIE ---------- */
  li  t0, 0x1801            /* MPP=M, SIE=1 (bit 0) */
  csrw mstatus, t0
  la  t0, test_a_done
  csrw mepc, t0
  mret
  .align 2
test_a_done:                /* M-mode after MRET */
  csrr t0, mstatus
  li   t6, 0xFFF
  and  t0, t0, t6
  li   t6, 0x81             /* MPIE=1, SIE=1, MIE=0, MPP=U */
  bne  t0, t6, fail_a

  /* ---------- Test B: MRET into S-mode with SIE=1 ---------- */
  li  t0, 0x801             /* MPP=S, SIE=1 (bit 0) */
  csrw mstatus, t0
  la  t0, test_b_entry
  csrw mepc, t0
  mret
  .align 2
test_b_entry:                /* S-mode after MRET */
  csrr t0, sstatus
  andi t0, t0, 1            /* sstatus.SIE */
  li   t6, 1
  bne  t0, t6, fail_b
  PASS                      /* from S-mode; PMP_ALLOW_ALL above */

fail_a: FAIL(1)
fail_b: FAIL(2)
