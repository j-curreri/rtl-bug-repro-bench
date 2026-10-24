/* Reproducer for the hgatp unsupported-MODE write bug (CVA6, cv64a6_imafdch_sv39).
 *
 * Spec behaviour (H extension / RISC-V privileged spec):
 *   hgatp.MODE is WARL.  Writing a MODE value the hart does not support does NOT
 *   ignore the rest of the write the way it may for satp: the other fields are
 *   WARL in the normal sense, so VMID and PPN must be updated to the written
 *   values (masked to the supported widths) even when MODE is clamped.
 *
 * Bug in this core (core/csr_regfile.sv, CSR_HGATP case): the whole write is
 * committed only when MODE is a supported value, so an unsupported-MODE write
 * changes none of the fields (VMID and PPN keep their old values).
 *
 * This test, entirely in M-mode (M-mode is never translated, so toggling hgatp
 * cannot affect our own execution):
 *   1. writes a known baseline state:  MODE=0 (supported), VMID=0x1, PPN=0x4
 *   2. writes an unsupported MODE=0xf with new VMID=0x2, PPN=0x8
 *   3. reads hgatp back and checks VMID (bits 57:44) and PPN (bits 43:0)
 *
 *   correct core: VMID and/or PPN reflect the written values  -> PASS
 *   buggy core  : the write was ignored, VMID=0x1 and PPN=0x4 -> FAIL
 */
#include "test.h"

  .section .text
  .globl test_main
test_main:
  /* M-mode already has full memory access, but grant PMP access anyway. */
  PMP_ALLOW_ALL

  /* hgatp bit layout on this core (XLEN64, Sv39x4):
   *   [63:60] MODE   [59:58] reserved   [57:44] VMID (14 bits)   [43:0] PPN (44 bits)
   */

  /* Step 1: establish a known baseline.  MODE=0 is a supported value, so this
   * whole write is honoured on both cores: VMID=0x1, PPN=0x4. */
  li   t0, (0x1 << 44) | 0x4       /* MODE=0, VMID=0x1, PPN=0x4 */
  csrw hgatp, t0

  /* Step 2: write an UNSUPPORTED MODE (0xf) with new VMID=0x2, PPN=0x8.
   * Correct core still updates VMID and PPN; buggy core ignores the write. */
  li   t0, (0xf << 60) | (0x2 << 44) | 0x8
  csrw hgatp, t0

  /* Step 3: read the register back. */
  csrr a0, hgatp

  /* Check VMID (bits 57:44).  A correct core reports the written 0x2. */
  srli a1, a0, 44
  li   t3, 0x3fff
  and  a1, a1, t3
  li   t1, 0x2
  bne  a1, t1, check_ppn
  PASS

check_ppn:
  /* Check PPN (bits 43:0).  A correct core reports the written 0x8. */
  li   t3, 0xfffffffffff           /* 44-bit mask = (1<<44)-1 */
  and  a2, a0, t3
  li   t2, 0x8
  bne  a2, t2, fail
  PASS

fail:
  FAIL(3)
