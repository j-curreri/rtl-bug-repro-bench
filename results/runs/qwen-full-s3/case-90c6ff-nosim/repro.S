#include "hyp.h"

/* Reproduce: with G-stage translation enabled and VS-stage translation off
 * (vsatp = Bare), VS-mode cannot execute code at some valid guest-physical
 * addresses: instruction fetch raises a page fault.
 *
 * Root cause: in the MMU instruction interface, the canonical-address check
 * tests fetch_vaddr[VLEN-1:SV-1] (bits [63:38]) for all-zeros or all-ones.
 * That is correct for a 39-bit virtual address, but when only G-stage
 * translation is active the "virtual address" presented to the MMU is a
 * guest-physical address: Sv39x4 GPAs are 41 bits wide and zero-extended,
 * so bits [40:38] may be set freely.  For a zero-extended GPA, bits
 * [63:38] are all-zero only when [40:38] = 00b, and all-one is impossible
 * (bit 63 = 0), so every G-only fetch at GPA >= 2^38 fails the check and
 * raises an instruction page fault on the buggy core.
 *
 * Strategy: set up a G-stage (Sv39x4) 1 GiB leaf mapping
 *   GPA [2^38, 2^38 + 1G) -> HPA 0x80000000   (root index 256)
 * plus
 *   GPA [0, 1G)           -> HPA 0x80000000   (root index 0, used by _halt)
 * enter VS-mode with mepc = GVA = 2^38 + off (off = HPA(vs_code) - 0x80000000),
 * and let the VS-mode code simply run to PASS.
 *
 * Correct core: the G-only fetch at GVA >= 2^38 is legal; PTW walks the
 * G-stage root (index 256) to the 1 GiB leaf, fetches from HPA 0x80000000,
 * and the program ends with PASS.
 *
 * Buggy core: the first VS-mode fetch raises an instruction page fault;
 * since hedeleg = 0 the guest exception escalates to M-mode at mtvec,
 * where trap_handler ends the run with FAIL.
 */

HYP_TABLES

  .text
  .globl test_main
  .align 2
test_main:
  PMP_ALLOW_ALL

  /* G-stage 1 GiB leaves (Sv39x4 root table, 2048 entries): */
  GIGA_LEAF(g_root, 0,   0x80000000, G_RWX)  /* GPA [0, 1G)          -> HPA 0x80000000 */
  GIGA_LEAF(g_root, 256, 0x80000000, G_RWX)  /* GPA [2^38, 2^38+1G)  -> HPA 0x80000000 */

  HGATP_ON

  /* mret into VS-mode: mstatus.MPV=1, MPP=S.  mepc holds a GVA:
   * GVA = HPA(vs_code) + (2^38 - 0x80000000) = HPA + 0x3C00000000,
   * i.e. GVA = 2^38 + off with off = HPA(vs_code) - 0x80000000. */
  li t0, MSTATUS_MPV
  csrs mstatus, t0
  li t0, (3 << 11)
  csrc mstatus, t0          /* MPP = 0, MPIE = 0 */
  li t0, (1 << 11)
  csrs mstatus, t0          /* MPP = S */
  la t1, vs_code
  li t0, 0x3F80000000
  add t1, t1, t0            /* t1 = GVA = 2^38 + off */
  csrw mepc, t1
  mret

  .align 2
vs_code:
  /* Reached in VS-mode at GVA = 2^38 + off: the G-only instruction fetch at
   * this guest-physical address succeeded. */
  PASS

  .align 2
  .globl trap_handler
trap_handler:
  /* Guest exception from the VS-mode fetch (hedeleg = 0 -> M-mode trap with
   * mstatus.MPV = 1).  A correct core never gets here. */
  csrr t6, mcause
  FAIL(127)
