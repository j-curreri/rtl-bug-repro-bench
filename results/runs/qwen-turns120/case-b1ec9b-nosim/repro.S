/* Reproduce: MRET that returns from M-mode to S-mode fails to clear MSTATUS.MPRV.
 *
 * The RISC-V privileged spec requires that MRET, when it returns to a privilege
 * mode less privileged than M, clears MPRV. On this core the clear is only
 * performed in the hypervisor build (it sits inside the RVH-only branch of the
 * MRET logic in csr_regfile.sv), so with RVH=0 MPRV survives the MRET to S-mode.
 *
 * Consequence exploited here: after the MRET, MPP has been reset to U, so every
 * later M-mode load/store is PMP-checked as a U-mode access ("as if MPRV were
 * still in effect").
 *
 * Plan:
 *  1. PMP entry 0: 128 KiB NAPOT region at 0x80080000 with no R/W/X -> denies
 *     S/U-mode accesses there (M-mode is unaffected).
 *  2. PMP entry 1: all-space NAPOT region with R/W/X -> allows S/U-mode
 *     accesses anywhere else.
 *  3. Set MPRV=1, MPP=S and MRET into S-mode.
 *       - spec-compliant core: MPRV is cleared by the MRET.
 *       - buggy core:         MPRV stays 1, MPP stays U.
 *  4. In S-mode: set SPP=M and SRET back to M-mode (SRET never clears MPRV).
 *  5. In M-mode: load from 0x80080000.
 *       - spec-compliant core: MPRV=0, M-mode -> PMP bypass -> load succeeds,
 *         the MPRV bit is observed to be 0 -> PASS.
 *       - buggy core: MPRV=1, MPP=U -> access PMP-checked as U-mode -> entry 0
 *         denies it -> load access fault -> trap -> FAIL.
 *
 * PMP CSR encoding on this core (cva6): pmpcfg entry = bit 7 L, bits [4:3]
 * address mode (00 off, 01 TOR, 10 NA4, 11 NAPOT), bit 2 R, bit 1 W, bit 0 X.
 * pmpaddr for a NAPOT region [A, A+S) (S = 2^(t+3)): (A>>2) + (S>>3) - 1.
 */
#include "test.h"

  .text
  .align 2
  .globl test_main
test_main:
  /* PMP entry 0: 128 KiB @ 0x80080000, NAPOT, no permissions.
   * pmpaddr = (0x80080000 >> 2) + (0x20000 >> 3) - 1 = 0x20023FFF */
  li t0, 0x20023FFF
  csrw pmpaddr0, t0
  /* PMP entry 1: whole address space, NAPOT, RWX. */
  li t0, -1
  csrw pmpaddr1, t0
  /* entry 0: NAPOT, no R/W/X; entry 1: NAPOT, R/W/X (both unlocked) */
  li t0, 0x1F18
  csrw pmpcfg0, t0

  /* Set MPRV just before the MRET; a spec-compliant core must clear it when
   * MPP=S.  MSTATUS.MPRV is bit 17. */
  li t0, 0x20000
  csrs mstatus, t0
  ENTER_MODE(1, s_enter)

s_enter:
  /* We must now be in S-mode.  Sanity: data memory still accessible from
   * S-mode (PMP entry 1 grants RWX everywhere else). */
  la t0, known
  ld t1, 0(t0)
  li t2, 0xdeadbeef
  bne t1, t2, s_fail
  /* Return to M-mode: SSTATUS.SPP = M (bit 8), then SRET. */
  csrs sstatus, 8
  la t0, m_check
  csrw sepc, t0
  sret

s_fail:
  FAIL(7)

m_check:
  /* Reading MSTATUS is only legal in M-mode; reaching this point without
   * trapping proves the SRET returned to M-mode. */
  csrr t0, mstatus

  /* Probe load at 0x80080000:
   *  - spec-compliant core: MPRV=0 -> M-mode access, PMP bypass -> succeeds.
   *  - buggy core: MPRV=1, MPP=U -> access PMP-checked as U-mode ->
   *    entry 0 denies it -> load access fault -> trap -> FAIL(5). */
  lui t0, 0x80080
  lw t1, 0(t0)

  /* MPRV must have been cleared by the MRET to S-mode; the SRET back to
   * M-mode does not clear it, so it must still read 0 here. */
  csrr t0, mstatus
  srli t0, t0, 17
  andi t0, t0, 1
  bnez t0, mprv_stuck
  PASS

mprv_stuck:
  FAIL(3)

/* The only trap expected is the probe load access fault on the buggy core;
 * anything else indicates a different failure. */
  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 5
  beq t0, t1, probe_fault
  FAIL(127)
probe_fault:
  FAIL(5)

  .data
  .align 3
known: .dword 0xdeadbeef
