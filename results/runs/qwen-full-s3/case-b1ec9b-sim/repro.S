/* MPRV-not-cleared-by-MRET reproducer for cv64a6_imafdc_sv39.
 *
 * The RISC-V privileged spec requires MRET to clear MPRV when it returns
 * to a privilege level less privileged than M (i.e. any MRET).  This core
 * only clears MPRV on MRET when the H extension is compiled in
 * (core/csr_regfile.sv, MRET block: `if (CVA6Cfg.RVH) ... mstatus_d.mprv
 * = 1'b0`), but this configuration has CVA6ConfigHExtEn = 0, so a stale
 * MPRV=1 survives MRET.
 *
 * Strategy:
 *   - M-mode: PMP allows all; build a Sv39 table with a single 1 GiB leaf
 *     mapping the program area to itself, WITHOUT the U bit; enable satp.
 *     M-mode accesses with MPRV=0 are untranslated, so this is invisible
 *     to M-mode code.
 *   - Store a known value (bare M-mode store).
 *   - Set MPRV=1 and MPP=S, then MRET into S-mode.  Spec: MPRV cleared.
 *   - S-mode: ecall -> M-mode trap (mcause = -9).
 *   - M-mode trap handler: the test load must be a plain M-mode access.
 *       * correct core: MPRV was cleared by MRET -> bare load -> PASS.
 *       * buggy core:   MPRV still 1, and MRET left MPP=U, so the load is
 *         translated through satp at U privilege; the PTE has no U bit
 *         -> load page fault (mcause = 13) -> FAIL(1).
 */
#include "test.h"
#include "hyp.h"

  .section .data
  .align 12
pt_root: .space 4096
test_word: .dword 0

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* 1 GiB leaf: VA 0x80000000..0xBFFFFFFF -> PA 0x80000000,
   * flags V|R|W|X|A|D, no U (so U-privileged accesses fault). */
  GIGA_LEAF(pt_root, 2, 0x80000000, VS_RWX)

  /* Enable Sv39; M-mode access stays untranslated while MPRV=0. */
  la t0, pt_root
  srli t0, t0, 12
  li t1, SATP_SV39
  or t0, t0, t1
  csrw satp, t0

  /* Known value, written with a bare M-mode store. */
  li t1, 0xA55A
  la t0, test_word
  sd t1, 0(t0)

  /* Set MPRV=1 (MPP is still M, so M-mode stays untranslated), then
   * MRET to S-mode with MPP=S.  A spec-compliant MRET clears MPRV. */
  li t0, (1 << 17)
  csrs mstatus, t0
  ENTER_MODE(1, s_ecall)

s_ecall:
  ecall

/* M-mode trap entry.  The only expected trap is the S-mode ecall above. */
  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, -9
  bne t0, t1, bad_cause

  /* Plain M-mode load of test_word.  With MPRV correctly cleared this
   * hits the physical address directly.  With a stale MPRV=1 (MPP=U)
   * it is a U-privileged load through satp and must page-fault. */
  la t2, test_word
  ld t2, 0(t2)
  li t3, 0xA55A
  bne t2, t3, bad_value

  li t4, (1 << 17)
  csrc mstatus, t4
  PASS

bad_cause:
  /* MPRV still set (bug visible): drop it so the tohost store below
   * is a bare M-mode access. */
  li t4, (1 << 17)
  csrc mstatus, t4
  FAIL(1)

bad_value:
  li t4, (1 << 17)
  csrc mstatus, t4
  FAIL(2)
