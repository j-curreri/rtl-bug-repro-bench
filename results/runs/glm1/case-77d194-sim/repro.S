/* repro.S - reproducer for the hgatp WARL bug of this CVA6 core.
 *
 * Bug (core/csr_regfile.sv, CSR_HGATP branch of the CSR write logic):
 *
 *     hgatp = hgatp_t'(csr_wdata);
 *     hgatp[1:0] = 2'b0;
 *     hgatp.vmid = ...;
 *     // "only update if we actually support this mode"
 *     if (config_pkg::vm_mode_t'(hgatp.mode) == config_pkg::ModeOff ||
 *                   config_pkg::vm_mode_t'(hgatp.mode) == CVA6Cfg.MODE_SV)
 *       hgatp_d = hgatp;                     // <-- WHOLE write dropped
 *
 * When the written MODE is not supported (anything besides Bare=0 and
 * Sv39x4=8 here), the entire write is discarded, exactly like satp.  The
 * hypervisor spec says hgatp must behave differently from satp: such a write
 * is NOT ignored, hgatp is WARL in the normal way, i.e. with an unsupported
 * MODE the VMID and PPN fields of the written value still take effect (and
 * MODE ends up as some supported value).
 *
 * Reproducer: entirely in M-mode, using nothing but architectural WARL
 * read-back (which is exactly how the spec tells software to probe hgatp).
 *
 *   1. Baseline: clear hgatp with a supported MODE=Bare write -> hgatp = 0
 *      (this write is honored on buggy and correct cores alike).
 *   2. Sanity probe: a supported-MODE (Sv39x4) write sticks in every field.
 *   3. Two probes write hgatp with reserved MODE values (0x1 and 0xf) and
 *      distinctive VMID/PPN.  A spec-correct core keeps the new VMID/PPN, so
 *      hgatp reads back nonzero -> PASS.  The buggy core ignores the whole
 *      write (satp-style), hgatp stays 0 -> FAIL.
 *
 * No trap is expected anywhere; the (own) trap handler reports mcause.
 */
#include "test.h"

  .section .text
  .globl test_main, trap_handler

  .align 2
trap_handler:
  csrr a0, mcause                 /* unexpected trap -> tohost = mcause      */
  slli a0, a0, 1
  ori  a0, a0, 1
  j    _halt

test_main:
  /* ---- baseline: hgatp = 0 via a supported-MODE (Bare) write ---- */
  csrw hgatp, x0

  /* ==== sanity probe: supported MODE (Sv39x4=8) sticks in all fields ====
   * write MODE=8, VMID=0x15, PPN=0x1000; read back and check each field. */
  li   t0, 0x1000                 /* PPN (bits 43:0, 16KiB-aligned)          */
  li   t1, 0x15
  slli t1, t1, 44
  or   t0, t0, t1                 /* VMID (bits 57:44)                       */
  li   t1, 8
  slli t1, t1, 60
  or   t0, t0, t1                 /* MODE (bits 63:60)                       */
  csrw hgatp, t0
  csrr t1, hgatp
  li   t2, -1
  srli t2, t2, 20                 /* one mask for PPN bits 43:0              */
  and  t2, t2, t1
  li   t3, 0x1000
  beq  t2, t3, 1f
  FAIL(10)
1:
  srli t2, t1, 44
  slli t2, t2, 50
  srli t2, t2, 50                 /* VMID field                              */
  li   t3, 0x15
  beq  t2, t3, 1f
  FAIL(11)
1:
  srli t2, t1, 60
  li   t3, 8
  beq  t2, t3, 1f
  FAIL(12)
1:

  /* ======== probe 1: reserved MODE=0x1, VMID=0x15, PPN=0x1000 ======== */
  csrw hgatp, x0                  /* back to baseline 0                      */
  li   t0, 0x1000
  li   t1, 0x15
  slli t1, t1, 44
  or   t0, t0, t1
  li   t1, 1
  slli t1, t1, 60                 /* MODE = 0x1 (reserved)                   */
  or   t0, t0, t1
  csrw hgatp, t0
  csrr t1, hgatp

  bnez t1, 1f                     /* write must not be ignored entirely      */
  FAIL(20)
1:
  li   t2, -1
  srli t2, t2, 20
  and  t2, t2, t1                 /* PPN must have taken the written value   */
  li   t3, 0x1000
  beq  t2, t3, 1f
  FAIL(21)
1:
  srli t2, t1, 44
  slli t2, t2, 50
  srli t2, t2, 50                 /* VMID must have taken the written value  */
  li   t3, 0x15
  beq  t2, t3, 1f
  FAIL(22)
1:

  /* ======== probe 2: reserved MODE=0xf, VMID=0x2a, PPN=0x2000 ======== */
  csrw hgatp, x0
  li   t0, 0x2000
  li   t1, 0x2a
  slli t1, t1, 44
  or   t0, t0, t1
  li   t1, 0xf
  slli t1, t1, 60                 /* MODE = 0xf (reserved)                   */
  or   t0, t0, t1
  csrw hgatp, t0
  csrr t1, hgatp

  bnez t1, 1f
  FAIL(30)
1:
  li   t2, -1
  srli t2, t2, 20
  and  t2, t2, t1
  li   t3, 0x2000
  beq  t2, t3, 1f
  FAIL(31)
1:
  srli t2, t1, 44
  slli t2, t2, 50
  srli t2, t2, 50
  li   t3, 0x2a
  beq  t2, t3, 1f
  FAIL(32)
1:

  PASS