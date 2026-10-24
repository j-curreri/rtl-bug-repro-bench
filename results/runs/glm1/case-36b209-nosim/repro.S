/*
 * repro.S - bug reproducer for the CVA6 core (cv64a6_imafdch_sv39).
 *
 * Bug reproduced:
 *   In VS-mode with two-stage translation, a load whose VS-stage walk
 *   reaches a non-leaf PTE pointing outside the guest-physical address
 *   space must raise a LOAD GUEST-PAGE FAULT (mcause = 21).
 *
 *   cva6_ptw.sv, PTE_LOOKUP's "pointer to next level" branch checks the
 *   upper PPN bits (ppn[43:29] != 0 while in S_STAGE, i.e. the next-level
 *   guest-physical address crosses the Sv39x4 gPA bound of 2^41/CVA6Cfg.GPLEN
 *   but only sets `state_d = PROPAGATE_ERROR` while keeping
 *   `ptw_stage_d = ptw_stage_q` (S_STAGE). PROPAGATE_ERROR then asserts
 *   ptw_error_o WITHOUT ptw_error_at_g_st_o, so cva6_mmu.sv reports an
 *   ordinary LOAD PAGE FAULT (mcause = 13) instead of the spec-required
 *   guest-page fault. (The twin check in the leaf branch correctly forces
 *   G_FINAL_STAGE, which is why only the non-leaf case is broken.)
 *
 * What the program does:
 *   1. In M-mode: allow S/VS access to memory (PMP), install a 1 GiB
 *      G-stage identity mapping, enable hgatp (Sv39x4).
 *   2. Install a VS-stage root with
 *         [2] 1 GiB leaf : VA 0x80000000.. -> gPA 0x80000000..  (code/data)
 *         [1] non-leaf pointer PTE whose next-level pointer is gPA 2^42,
 *             far outside the 41-bit Sv39x4 guest-physical space.
 *      Its A/D/U bits are kept clear so only the reported bug is exercised.
 *   3. Enable vsatp and drop into VS-mode, then load from VA 0x40001000
 *      (VPN2 == 1 -> the pointer PTE above). On correct RTL the walk ends
 *      in a guest-page fault; the flawed walk ends in a plain page fault.
 *      All traps go straight to the M-mode handler (medeleg is 0), which
 *      PASSes iff mcause == 21, and otherwise FAILs with the observed cause.
 */
#include "test.h"
#include "hyp.h"

  .section .text
  .globl test_main
test_main:
  /* S/VS-mode code may run and touch DRAM. */
  PMP_ALLOW_ALL

  /* G-stage (Sv39x4): gPA 0x80000000..0xBFFFFFFF -> PA 0x80000000 (1 GiB leaf). */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  HGATP_ON

  /* VS-stage (Sv39):
   *   [2] 1 GiB leaf   : VA 0x80000000.. -> gPA 0x80000000.. (code/data)
   *   [1] non-leaf PTE : next-level pointer = gPA 2^42, i.e. ppn[43:29] != 0,
   *                      outside the 2^41 Sv39x4 guest-physical space. */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  RAW_PTE(vs_root, 1, ((0x40000000000 >> 12) << 10) | PTE_V)
  fence

  la s1, vs_root
  VSATP_ON(s1)

  /* Enter VS-mode. MPV is set by ENTER_VS; a trap clears V (and the
   * handler forgoes any return). */
  ENTER_VS(test_vs)

/* Runs in VS-mode. */
test_vs:
  li   t0, 0x40001000      /* VPN2 == 1 -> vs_root[1]: the out-of-range pointer PTE */
  ld   t1, 0(t0)           /* correct RTL: mcause 21 / buggy RTL: mcause 13          */
  ecall                    /* only reached if the load did not trap: FAIL(mcause=9)  */

/* Global M-mode trap handler (mtvec target set by crt.S).  Traps from
 * VS-mode land here because medeleg is zero.  No return: this call is the
 * pass/fail decision itself. */
  .globl trap_handler
  .align 2
trap_handler:
  csrr t6, mcause          /* the required cause for this load is 21 */
  li   t5, 21
  beq  t6, t5, pass
  /* Wrong cause (13 on the buggy core) or another exception: FAIL(mcause). */
  slli a0, t6, 1
  ori  a0, a0, 1
  j    _halt
pass:
  PASS

/* G- and VS-stage roots. g_root[0] stays V=0, so on a core fixed by
 * letting the walk continue into the G-stage the out-of-range pointer
 * still terminates in a guest-page fault. */
HYP_TABLES