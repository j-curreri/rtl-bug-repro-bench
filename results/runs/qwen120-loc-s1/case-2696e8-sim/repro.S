#include "test.h"
#include "hyp.h"

/* Reproduction of a G-stage (second-stage) LOAD permission bug in
 * core/cva6_mmu/cva6_mmu.sv.
 *
 * On the DTLB-hit path a G-stage load only checks the U flag
 * (d_g_st_access_err) plus the S-stage daccess_err/canonical checks. It never
 * re-checks the G-stage read permission (pte.r, or pte.x with MXR/HLVX):
 * `g_load_access_ok` is computed (cva6_mmu.sv ~line 571) but is never used in
 * the load permission check. Consequently an execute-only G-stage leaf PTE
 * (X=1, R=0) wrongly allows a plain load to succeed where the RISC-V spec
 * requires a LOAD guest-page fault.
 *
 * The MMU's mxr_i is mstatus.MXR (M-mode only). So the exploit:
 *   - G-stage 1 GiB leaf PTE: V, X, U, A set; R, W, D clear (exec-only).
 *   - M-mode: mstatus.MXR = 1, then mret into HS mode.
 *   - HS-mode hlv.d on guest address GA: X + MXR grants read -> the PTE is
 *     walked by the PTW and cached in the DTLB (tag v_st_enbl={1,1,0}).
 *     (hlv.d, not hlv.w, so the marker address is not sign-extended.)
 *   - ecall back to M-mode to clear mstatus.MXR, resume in HS mode.
 *   - HS-mode hlv.d on the same GA: DTLB hit (MXR now 0).
 *       * Correct core: DTLB-hit load re-checks R=0 (no MXR) -> guest page
 *         fault (mcause = load guest-page fault) -> handler -> PASS.
 *       * Buggy core: DTLB-hit load skips the R check -> load succeeds
 *         -> program continues -> FAIL.
 *
 * The second hlv's address is derived from the first hlv's result (a register
 * dependency), so the out-of-order core issues it only after the first hlv has
 * retired and the DTLB entry is populated -> a reliable DTLB hit, not a fresh
 * page-table walk (a walk would fault on both cores and mask the bug).
 */

/* Execute-only G-stage PTE flags: V|X|U|A = 0x59 (R, W, D, G clear). */
#define G_X_ONLY  (PTE_V | PTE_X | PTE_U | PTE_A)
/* Test guest/physical address (identity G-stage mapping; in DRAM). */
#define TEST_ADDR 0x80100000
/* mstatus.MXR bit. */
#define MXR_BIT   (1 << 19)

HYP_TABLES

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* Put the marker (== TEST_ADDR) at PA TEST_ADDR so the first hlv result
   * yields the guest address again (creates the hlv -> hlv dependency). */
  li   t0, TEST_ADDR
  sd   t0, 0(t0)
  fence
  /* G-stage 1 GiB leaf at g_root[TEST_ADDR >> 30] = g_root[2]; PA base 0x8000_0000. */
  GIGA_LEAF(g_root, 2, 0x80000000, G_X_ONLY)
  /* Enable G-stage translation (Sv39x4, VMID 0). */
  HGATP_ON
  /* mstatus.MXR = 1 -> feeds the MMU mxr_i for the first hlv. */
  li   t0, MXR_BIT
  csrs mstatus, t0
  /* mret into HS mode (v=0, S privilege, MPV=0 -> not guest mode). */
  ENTER_MODE(1, hs_body)

/* HS mode: first hlv caches the exec-only PTE; ecall clears MXR; second hlv
 * then hits the DTLB. */
hs_body:
  li    t1,  TEST_ADDR
  /* hlv.d (not hlv.w): a 64-bit load keeps a0 canonical (0x80100000);
   * hlv.w would sign-extend it to 0xFFFF_80100000 (non-canonical). */
  hlv.d a0, 0(t1)      /* MXR=1: X+MXR read ok; DTLB cached; a0 = marker = TEST_ADDR */
ecall_pt:
  ecall               /* trap to M-mode to clear MXR */
after_ecall:
  hlv.d a1, 0(a0)      /* MXR=0: DTLB hit. Correct core: guest page fault. Buggy: ok. */
  # Only reached on the buggy core, where the second hlv did not fault.
  FAIL(1)

/* M-mode handler. */
  .globl trap_handler
  .align 2
trap_handler:
  csrr t6, mcause
  csrr t5, mepc
  # The second hlv faulting? (mepc == address of that hlv == after_ecall)
  la   x28, after_ecall
  beq  t5, x28, check_fault
  # The intentional ecall? (mepc == address of the ecall instruction)
  la   x28, ecall_pt
  beq  t5, x28, handle_ecall
  # Any other trap is unexpected.
  FAIL(127)
handle_ecall:
  li   x28, MXR_BIT
  csrc mstatus, x28    # clear mstatus.MXR
  la   x28, after_ecall
  csrw mepc, x28       # resume after the ecall
  mret
check_fault:
  li   x28, 21         /* this core's riscv::LOAD_GUEST_PAGE_FAULT */
  beq  t6, x28, repro_pass
  li   x28, 13         /* standard RISC-V load guest-page fault (safety) */
  beq  t6, x28, repro_pass
  FAIL(127)
repro_pass:
  PASS
