/* repro.S - reproducer for the CVA6 H-GATP write bug.
 *
 * Bug (see TASK.md):
 *   Writing H-GATP with an unsupported MODE value is ignored *entirely*: none of
 *   the other fields (PPN, VMID) change. The hypervisor spec instead says the
 *   fields of H-GATP are WARL in the normal way, i.e. PPN and VMID are written to
 *   their (legalized) written values even when the MODE field is unsupported.
 *
 * This core (cv64a6_imafdch_sv39) only supports MODE = Off (0) and Sv39 (8).
 * Any other MODE value (1,2,3,...,7,9,...,15) is "unsupported".
 *
 * H-GATP bit layout on RV64 (from the hgatp_t struct in csr_regfile.sv):
 *   bits [63:60] = MODE
 *   bits [59:58] = warl0 (unused)
 *   bits [57:44] = VMID
 *   bits [ 43:0] = PPN   (PPN[1:0] hardwired to 0)
 *
 * Strategy:
 *   Phase 1: write a SUPPORTED value  {MODE=Sv39, PPN=4}  -> PPN baseline = 4.
 *   Phase 2: write an UNSUPPORTED mode {MODE=Sv48, PPN=0} -> per spec PPN=0.
 *   Phase 3: read H-GATP back:
 *              - conforming core: PPN was written  -> PPN == 0 -> PASS
 *              - buggy core    : write ignored     -> PPN still 4 -> FAIL
 */
#include "test.h"

  .section .text
  .globl test_main
  .align 2
test_main:
  /* ---- Phase 1: establish a non-zero PPN baseline with a supported MODE ---- */
  li   t0, 8                   /* MODE = Sv39 = 8 (supported)                */
  slli t0, t0, 60              /* t0 = 8 << 60 = 0x8000_0000_0000_0000        */
  li   t1, 4                   /* PPN = 4 (PPN[1:0]=0, non-zero)             */
  or   t0, t0, t1              /* t0 = {MODE=8, PPN=4, VMID=0}               */
  csrw hgatp, t0
  csrr t2, hgatp
  bne  t2, t0, 1f             /* sanity: a supported write must read back    */
  j    2f
1:
  FAIL(1)

2:
  /* ---- Phase 2: write an UNSUPPORTED MODE (Sv48 = 9) with PPN = 0 ---- */
  li   t0, 9                   /* MODE = Sv48 = 9 (unsupported on this core)  */
  slli t0, t0, 60              /* t0 = 9 << 60 = 0x9000_0000_0000_0000        */
  csrw hgatp, t0              /* {MODE=9, PPN=0, VMID=0}                     */
  csrr t2, hgatp

  /* ---- Phase 3: PPN must reflect the written value (0) on a conforming core.
   *      The buggy core ignores the whole write, so PPN remains 4. ---- */
  li   t3, -1
  srli t3, t3, 20             /* t3 = 0x0000_0FFFF_FFFF_FFFF (44-bit PPN mask) */
  and  t4, t2, t3            /* t4 = PPN field                                */
  bnez t4, 3f               /* PPN != 0 -> write was ignored -> buggy        */
  PASS

3:
  FAIL(2)

  /* Override the default trap handler: any trap is a non-PASS outcome. */
  .globl trap_handler
  .align 2
trap_handler:
  FAIL(130)
