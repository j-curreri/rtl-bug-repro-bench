/* PMP address readback in NAPOT mode.
 *
 * Privileged spec (PMP granularity): with grain G, bits pmpaddr[G-1:0] read as
 * zero in OFF/TOR mode, and only bits pmpaddr[G-2:0] read as one in NAPOT mode.
 * For G=1 no bit is forced in NAPOT mode: pmpaddr reads back exactly as written.
 *
 * The buggy core reports G=1 (OFF readback clears only bit 0) but forces bit 0
 * to 1 when the entry is NAPOT, i.e. it reports a 16-byte region where an 8-byte
 * one was programmed (and is enforced by the PMP unit).
 *
 * G is determined at run time, so any spec-conforming granularity passes.
 */
#include "test.h"

#define NAPOT_ADDR 0x20001000   /* low 12 bits clear */

  .text
  .globl test_main
test_main:
  /* All entries OFF, no locks. */
  csrw pmpcfg0, zero

  /* Grain: write all ones in OFF mode; the lowest set bit of the readback is G. */
  li t0, -1
  csrw pmpaddr1, t0
  csrr s0, pmpaddr1
  beqz s0, fail_nopmp
  li s1, 0                      /* s1 = G */
1:
  srl t1, s0, s1
  andi t1, t1, 1
  bnez t1, 2f
  addi s1, s1, 1
  j 1b
2:
  li t0, 12
  bgeu s1, t0, fail_grain       /* NAPOT_ADDR assumes G < 12 */

  /* Expected NAPOT readback: written value with bits [G-2:0] set (none if G=1). */
  li s2, NAPOT_ADDR
  beqz s1, 3f
  addi t1, s1, -1
  li t2, 1
  sll t2, t2, t1
  addi t2, t2, -1
  or s2, s2, t2
3:
  /* Entry 1: NAPOT, no permissions, unlocked (does not affect M-mode). */
  li t0, NAPOT_ADDR
  csrw pmpaddr1, t0
  li t0, (0x18 << 8)
  csrw pmpcfg0, t0

  csrr t1, pmpcfg0
  srli t1, t1, 8
  andi t1, t1, 0xff
  li t0, 0x18
  bne t1, t0, fail_cfg

  csrr s3, pmpaddr1
  bne s3, s2, fail_addr

  /* Back to OFF: bits [G-1:0] must read as zero again. */
  csrw pmpcfg0, zero
  csrr s4, pmpaddr1
  li t0, NAPOT_ADDR
  bne s4, t0, fail_off

  PASS

fail_nopmp: FAIL(1)
fail_grain: FAIL(2)
fail_cfg:   FAIL(3)
fail_addr:  FAIL(4)
fail_off:   FAIL(5)
