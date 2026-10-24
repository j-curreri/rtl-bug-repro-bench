#include "test.h"
/* mstatus field legality on an M+U (no S-mode) RV64 core with F/D. */
  .text
  .globl test_main
test_main:
  /* Write all ones except MBE/SBE/UBE (keep little-endian), MPRV and MIE. */
  li t0, -1
  li t1, (1 << 37) | (1 << 36) | (1 << 17) | (1 << 6) | (1 << 3)
  not t1, t1
  and t0, t0, t1
  csrw mstatus, t0
  csrr s0, mstatus

  /* SXL (bits 35:34) must be read-only zero when S-mode is not supported. */
  srli t0, s0, 34
  andi t0, t0, 3
  bnez t0, fail_sxl

  /* UXL (bits 33:32) must be 2 (64-bit). */
  srli t0, s0, 32
  andi t0, t0, 3
  li t1, 2
  bne t0, t1, fail_uxl

  /* S-mode only fields must be zero: SIE, SPIE, SPP, SUM, MXR, TVM, TSR. */
  li t1, (1 << 1) | (1 << 5) | (1 << 8) | (1 << 18) | (1 << 19) | (1 << 20) | (1 << 22)
  and t0, s0, t1
  bnez t0, fail_sfields

  /* MPP was written 3 (M), legal. */
  srli t0, s0, 11
  andi t0, t0, 3
  li t1, 3
  bne t0, t1, fail_mpp

  /* MPP=S (1) is illegal without S-mode: must not read back as 1. */
  li t0, (3 << 11)
  csrc mstatus, t0
  li t0, (1 << 11)
  csrs mstatus, t0
  csrr t0, mstatus
  srli t0, t0, 11
  andi t0, t0, 3
  li t1, 1
  beq t0, t1, fail_mpp_s

  /* FS dirty => SD set. */
  li t0, (3 << 13)
  csrs mstatus, t0
  csrr t0, mstatus
  bgez t0, fail_sd
  li t0, (1 << 17) | (1 << 21)
  csrc mstatus, t0
  PASS

fail_sxl:     FAIL(1)
fail_uxl:     FAIL(2)
fail_sfields: FAIL(3)
fail_mpp:     FAIL(4)
fail_mpp_s:   FAIL(5)
fail_sd:      FAIL(6)
