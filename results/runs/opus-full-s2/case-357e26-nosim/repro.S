#include "test.h"

/*
 * PMP TOR grain bug reproducer (CVA6 cv64a6_imafdc_sv39, G=1 / 8-byte grain).
 *
 * The core masks pmpaddr's low bit to the grain only on CSR read-back; the
 * value actually used for TOR matching keeps the written low bit. So a TOR
 * top boundary written with bit0 set lands 4 bytes too high.
 *
 * We make PMP entry 1 a TOR DENY entry whose top boundary, written with the
 * low bit set, is nominally 0x80100000 (8-byte aligned) but becomes 0x80100004
 * on the buggy core. A lower-priority entry 7 grants RWX to everything.
 *
 * A U-mode load from X = 0x80100000:
 *   - correct core: X >= top(0x80100000) -> entry 1 does not match ->
 *     falls through to entry 7 -> allowed -> reach ecall -> PASS.
 *   - buggy core:   X <  top(0x80100004) -> entry 1 matches (deny) ->
 *     load access fault -> FAIL.
 */

#define X_ADDR   0x80100000      /* 8-byte aligned test address */

  .section .text
  .globl test_main
test_main:
  /* Seed the test location (M-mode bypasses unlocked PMP). */
  li   t0, X_ADDR
  li   t1, 0x1234
  sd   t1, 0(t0)

  /* Entry 0: OFF, only provides the TOR base for entry 1 = 0x800F0000. */
  li   t0, (0x800F0000 >> 2)
  csrw pmpaddr0, t0

  /* Entry 1: TOR top. (0x80100000>>2)|1 -> buggy<<2=0x80100004, correct=0x80100000 */
  li   t0, ((0x80100000 >> 2) | 1)
  csrw pmpaddr1, t0

  /* Entry 7: NAPOT covering all memory (grant fallback). */
  li   t0, -1
  csrw pmpaddr7, t0

  /* pmpcfg0: byte0=0x00 (OFF), byte1=0x08 (TOR,---), byte7=0x1f (NAPOT,RWX) */
  li   t0, 0x1f00000000000800
  csrw pmpcfg0, t0

  ENTER_MODE(0, u_entry)

  /* U-mode: the access under test, then signal success via ecall. */
u_entry:
  li   t0, X_ADDR
  lw   t1, 0(t0)
  ecall

  /* Trap handler (runs in M-mode). ecall-from-U => PASS; anything else FAIL. */
  .globl trap_handler
  .align 2
trap_handler:
  csrr t6, mcause
  li   t5, 8            /* ECALL from U-mode */
  beq  t6, t5, 1f
  FAIL(1)
1:
  PASS
