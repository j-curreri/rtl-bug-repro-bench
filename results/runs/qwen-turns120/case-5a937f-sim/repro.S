/*
 * repro.S — bug reproducer: menvcfg/senvcfg CBIE WARL violation.
 *
 * Bug report: the CBIE field of menvcfg (and senvcfg/henvcfg) can be left
 * holding the reserved encoding 2'b10 after software writes it. CBIE is a
 * WARL field and must never read back a reserved value: after a write of
 * 2'b10 a conforming core reads back one of the defined encodings
 * (2'b00, 2'b01 or 2'b11).
 *
 * This core places CBIE at bits [5:4] of the low half of menvcfg/senvcfg
 * (MENVCFG_CBIE mask = 0x30, see core/include/riscv_pkg.sv):
 *   CBIE[0] = bit 4,  CBIE[1] = bit 5.
 * Writing 2'b10 therefore sets menvcfg/senvcfg bit 5 only (value 0x20).
 *
 * Test (M-mode throughout):
 *   For each of menvcfg and senvcfg:
 *     1. read-modify-write so the CBIE field becomes 2'b10 (all other bits,
 *        notably FIOM bit 0, are preserved);
 *     2. read it back; if the field reads back 2'b10 the core retains a
 *        reserved encoding -> FAIL.
 *
 * CBIE only affects CBO.* (Zicbom) instructions, of which this test runs
 * none, so writing it has no side effect on execution. No trap is expected
 * on any conforming core; an unexpected trap also fails the test.
 *
 * Codes: FAIL(1) menvcfg.CBIE readback is reserved 2'b10
 *        FAIL(2) senvcfg.CBIE readback is reserved 2'b10
 *        FAIL(100+mcause) unexpected trap
 */

#include "test.h"

  .section .text
  .globl test_main

  .align 2
test_main:
  /* ---------- menvcfg.CBIE: write reserved 2'b10, readback must differ --- */
  csrr  t0, menvcfg            /* preserve all other bits (FIOM, ...) */
  andi  t1, t0, ~0x30          /* clear CBIE field */
  ori   t1, t1, 0x20           /* CBIE = 2'b10 (reserved encoding) */
  csrw  menvcfg, t1
  csrr  t2, menvcfg
  andi  t2, t2, 0x30           /* read back the CBIE field */
  li    t3, 0x20
  bne   t2, t3, menvcfg_ok
  FAIL(1)                      /* reserved encoding 2'b10 read back */
menvcfg_ok:

  /* ---------- senvcfg.CBIE: same WARL rule ----------------------------- */
  csrr  t0, senvcfg
  andi  t1, t0, ~0x30
  ori   t1, t1, 0x20           /* CBIE = 2'b10 (reserved encoding) */
  csrw  senvcfg, t1
  csrr  t2, senvcfg
  andi  t2, t2, 0x30
  li    t3, 0x20
  bne   t2, t3, senvcfg_ok
  FAIL(2)                      /* reserved encoding 2'b10 read back */
senvcfg_ok:

  PASS

  /* Any unexpected trap fails, reporting mcause as the code. */
  .globl trap_handler
  .align 2
trap_handler:
  csrr  t6, mcause
  addi  t6, t6, 100
  slli  t6, t6, 1
  ori   t6, t6, 1
  la    t0, tohost
  sd    t6, 0(t0)
1:  j 1b
