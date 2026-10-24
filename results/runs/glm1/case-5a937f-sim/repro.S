/* repro.S -- bug reproducer for the CVA6 core cv64a6_imafdc_sv39_hpdcache.
 *
 * Bug: the 2-bit CBIE field of menvcfg is a WARL field, but software write of
 * the reserved encoding 2'b10 leaves the field holding that reserved value,
 * which then reads back.  A specification-correct implementation must never
 * let a WARL field read back a reserved (unsupported) encoding: writing 10
 * has to read back as one of the legal encodings 00, 01 or 11.
 *
 * In this core the CBIE field lives at bits [5:4] of menvcfg (csr_regfile.sv
 * decodes csr_wdata[5:4] on write and exposes the register at csr_rdata[5:4];
 * the CBIE-as-written-2'b10 case is stored as riscv::CBIE_RSVD = 2'b10).
 *
 * The test:
 *   1. writes menvcfg bits [5:4] = 2'b10, preserving the remaining bits,
 *      then reads menvcfg back:
 *        - buggy core: field reads back 2'b10            -> FAIL(1)
 *        - correct core: field reads back 00/01/11       -> continue
 *   2. probe menvcfg bits [9:8] (the CBIE position per the RISC-V privileged
 *      spec) the same way -> FAIL(2) if 2'b10 reads back there,
 *   3. restores a legal CBIE encoding, then PASSes.
 * Any trap fails with a trap-derived code (>= 128).
 *
 * This file runs entirely in M-mode and does not rely on the H extension:
 * this configuration compiles without RVH, so henvcfg is absent (any access
 * to it would trap on a correct core, too).
 */

#include "test.h"

#define CSR_MENVCFG    0x30A

  .section .text
  .globl test_main
  .globl trap_handler

test_main:
  /* ---- menvcfg: write CBIE = 2'b10, read back ---- */
  csrr t0, CSR_MENVCFG
  li   t1, -0x31              /* ~0x30: clear bits [5:4] */
  and  t2, t0, t1
  ori  t2, t2, 0x20           /* [5:4] = 2'b10 (reserved CBIE encoding) */
  csrw CSR_MENVCFG, t2
  csrr t3, CSR_MENVCFG
  andi t4, t3, 0x30
  li   t5, 0x20               /* 2'b10 at [5:4] */
  bne  t4, t5, cbie_ok
  FAIL(1)
cbie_ok:
  /* ---- also probe CBIE at its spec position, menvcfg bits [9:8] ---- */
  csrr t0, CSR_MENVCFG
  li   t1, -0x301             /* ~0x300: clear bits [9:8] */
  and  t2, t0, t1
  ori  t2, t2, 0x200          /* [9:8] = 2'b10 */
  csrw CSR_MENVCFG, t2
  csrr t3, CSR_MENVCFG
  srli t4, t3, 8
  andi t4, t4, 0x3
  li   t5, 0x2
  bne  t4, t5, restore        /* must not read back the reserved encoding */
  FAIL(2)
restore:
  /* Restore a legal encoding (2'b00 maps to CBIE_ILLEGAL) once more. */
  csrr t0, CSR_MENVCFG
  li   t1, -0x31
  and  t2, t0, t1
  csrw CSR_MENVCFG, t2
  PASS

  .align 2
trap_handler:
  csrr t4, mcause
  li   t5, 0x7F
  and  t4, t4, t5
  slli t4, t4, 1
  ori  t4, t4, 1
  ori  t4, t4, 0x100          /* marker bit: trap codes are >= 128 */
  la   t0, tohost
  sd   t4, 0(t0)
1: j 1b