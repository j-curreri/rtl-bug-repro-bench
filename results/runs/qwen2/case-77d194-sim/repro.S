/* repro.S — hgatp WARL bug: writes with an unsupported MODE must not be ignored
 * entirely.
 *
 * Bug (core/csr_regfile.sv, CSR_HGATP write case): the new hgatp value is
 * committed only when the written MODE is supported (Bare or Sv39 for this
 * configuration). Writing any other MODE silently discards the whole value,
 * so PPN and VMID keep their old contents.
 *
 * Spec behaviour: hgatp fields are WARL in the normal way — a write with an
 * unsupported MODE still updates PPN (and VMID); only MODE itself is clamped
 * to a supported value. (This differs from satp, where a write with an
 * unsupported MODE is ignored in its entirety.)
 *
 * Test (runs entirely in M-mode, where hgatp is accessible and G-stage
 * translation never applies):
 *   1. hgatp = {MODE=Sv39, PPN=A}  (supported)  -> PPN must become A.
 *   2. hgatp = {MODE=Sv48, PPN=B}  (unsupported)-> PPN must become B.
 *   3. Read hgatp back: PPN == B  => PASS (spec-conformant core)
 *                        PPN == A  => FAIL (write was ignored: the bug)
 */
#include "test.h"

#define MODE_SV39   8          /* supported by this core (cv64a6_imafdch_sv39) */
#define MODE_SV48   9          /* unsupported MODE value */
#define PPN_A       0x10       /* page number, low two bits zero */
#define PPN_B       0x20       /* a different page number, low two bits zero */
/* hgatp layout of this core: MODE = bits [63:60], WARL = [59:58],
 * VMID = [57:44], PPN = [43:0] (bits [1:0] hardwired to 0). */

.macro hgatp_write mode, ppn
  li    t0, (\mode)
  slli  t0, t0, 60
  li    t1, (\ppn)
  or    t0, t0, t1
  csrw  hgatp, t0
.endm

.macro hgatp_ppn reg
  csrr  \reg, hgatp
  srli  \reg, \reg, 2
  andi  \reg, \reg, 0xff            /* PPN[7:0] */
.endm

  .text
  .globl test_main
test_main:
  /* --- step 0: at reset hgatp must read zero --- */
  hgatp_ppn t2
  bne t2, zero, fail_setup

  /* --- step 1: supported MODE (Sv39) with PPN = PPN_A --- */
  hgatp_write MODE_SV39, PPN_A
  hgatp_ppn t2
  li t3, (PPN_A >> 2)
  bne t2, t3, fail_sanity

  /* --- step 2: unsupported MODE (Sv48) with PPN = PPN_B ---
   * Spec: PPN is updated to PPN_B regardless of the clamped MODE.
   * Buggy core: the write is ignored, PPN stays PPN_A. */
  hgatp_write MODE_SV48, PPN_B
  hgatp_ppn t2
  li t3, (PPN_B >> 2)
  bne t2, t3, fail_bug

  /* PPN updated despite unsupported MODE: spec-conformant core. */
  PASS

  .align 2
fail_setup:
  FAIL(11)
  .align 2
fail_sanity:
  FAIL(10)
  .align 2
fail_bug:
  FAIL(1)
