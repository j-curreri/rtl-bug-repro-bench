/* repro.S -- bug reproducer for the CVA6 core (config cv64a6_imafdch_sv39).
 *
 * Bug (from the report): in VS-mode with two-stage translation, a load whose
 * VS-stage walk reaches a NON-LEAF PTE whose PPN points outside the
 * guest-physical address space is reported with the wrong exception cause.
 * The RISC-V spec requires a guest-page fault here; this core reports a plain
 * page fault.
 *
 * RTL detail (core/cva6_mmu/cva6_ptw.sv): when the VS-stage (S_STAGE) walker
 * examines a PTE whose PPN has any bit above the guest-PPN width set
 * (pte.ppn[PPNW-1:GPPNW] != 0, i.e. PPN[43:29] for this config, meaning the
 * PTE points outside the GPLEN=41 guest-physical space), it must flag the
 * error as a G-stage error so the MMU raises a *guest* page fault.
 *   - leaf PTE case    (cva6_ptw.sv:536-540): ptw_stage_d = G_FINAL_STAGE ->
 *     ptw_error_at_g_st = 1 -> LOAD_GUEST_PAGE_FAULT (mcause 21).  correct.
 *   - non-leaf PTE case (cva6_ptw.sv:598-601): ptw_stage_d = ptw_stage_q
 *     (= S_STAGE) -> ptw_error_at_g_st = 0 -> LOAD_PAGE_FAULT (mcause 13).
 *     THIS IS THE BUG.
 *
 * Strategy
 * --------
 * Set up G-stage (Sv39x4) + VS-stage (Sv39) two-stage translation:
 *   - g_root[2]  : 1 GiB G-stage leaf, identity-mapping the DRAM block that
 *                  holds our code and page tables (GPA 0x8000_0000 -> HPA).
 *   - vs_root[2] : 1 GiB VS-stage leaf, mapping our VS-mode code's virtual
 *                  addresses (VA 0x8000_0000..) to the same GPA (identity).
 *   - vs_root[5] : a VALID NON-LEAF PTE (v=1, r=x=0, a=d=u=0) whose PPN is
 *                  1<<32, i.e. PPN[43:29] != 0  ->  points OUTSIDE the GPA
 *                  space.
 * Then, in VS-mode, perform a load whose virtual address has VA[38:30] == 5.
 * The VS-stage walk fetches vs_root[5], sees a valid non-leaf PTE that points
 * outside the GPA space, and must raise a guest-page fault.
 *
 * The load fault is not delegated (medeleg/hedeleg reset to 0), so it is taken
 * to M-mode with the cause in mcause.  We check mcause:
 *   - correct core: mcause == 21 (LOAD_GUEST_PAGE_FAULT)  -> PASS
 *   - buggy   core: mcause == 13 (LOAD_PAGE_FAULT)        -> FAIL
 */
#include "hyp.h"

HYP_TABLES

  .section .text
  .align 2

  .globl test_main
test_main:
  /* M-mode: grant all of memory to S/U (and hence VS-mode) via PMP. */
  PMP_ALLOW_ALL

  /* G-stage (Sv39x4): identity-map the 1 GiB DRAM block at 0x8000_0000.
   * This covers both our executable code and the page tables. */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)

  /* VS-stage (Sv39), index 2: 1 GiB leaf mapping the VS-mode code's virtual
   * addresses (0x8000_0000 .. 0xC000_0000) to the matching GPA, which the
   * G-stage then maps back to the same HPA (identity end-to-end). */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)

  /* VS-stage (Sv39), index 5: the trigger.  A valid NON-LEAF PTE whose PPN
   * (1<<32) points outside the guest-physical address space.  PTE value:
   *   bit0 (v) = 1 ;  ppn field = (1<<32) << 10 = 1<<42 ;  everything else 0.
   *  0x40000000001  ==  (1<<42) | 1 */
  RAW_PTE(vs_root, 5, 0x40000000001)

  /* Enable two-stage translation. */
  HGATP_ON
  la   t0, vs_root
  VSATP_ON(t0)

  /* mret into VS-mode (V=1, S-mode) and run the faulting load there. */
  ENTER_VS(vs_load)

vs_load:
  /* Now in VS-mode with two-stage translation enabled.  Load through the bad
   * VS-stage PTE: VA[38:30] == 5 selects vs_root[5].  8-byte aligned so the
   * fault is a page fault, not a misaligned-address exception. */
  li   t1, 0x140001000        /* VA[38:30] = 5 */
  ld   t0, 0(t1)             /* two-stage walk -> bad non-leaf PTE -> trap */
  FAIL(5)                    /* should never be reached */

  /* M-mode trap handler (mtvec is set to this label by crt.S _start).  The
   * VS-mode load fault is not delegated, so it lands here with mcause set. */
  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li   t1, 21                /* LOAD_GUEST_PAGE_FAULT */
  bne  t0, t1, not_guest_fault
  PASS                       /* correct behaviour: guest-page fault (cause 21) */
not_guest_fault:
  FAIL(13)                   /* buggy behaviour: plain load page fault (cause 13) */
