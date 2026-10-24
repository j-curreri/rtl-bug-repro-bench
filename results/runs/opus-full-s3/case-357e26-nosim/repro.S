#include "test.h"

/*
 * PMP TOR grain bug (G=1, 8-byte grain).
 *
 * The RISC-V spec says that with a PMP grain of 8 bytes, bit 0 of a pmpaddr
 * register is not part of the TOR boundary address: a TOR boundary is always
 * rounded down to an 8-byte boundary. This core keeps the raw written value
 * (low bit included) for the address match, so writing a pmpaddr whose low bit
 * is set pushes the effective TOR boundary 4 bytes higher than the spec allows.
 *
 * Layout (all code/stack live below 0x80100000, covered by entry 0):
 *   entry0: TOR, top = 0x80100000            -> grants RWX to [0, 0x80100000)
 *   entry1: TOR, top written as 0x80102000|4 -> region [0x80100000, top1)
 *
 * pmpaddr1 = (0x80102000 >> 2) | 1 = 0x20040801
 *   correct core: bit0 ignored -> top1 = 0x80102000
 *   buggy  core: bit0 kept    -> top1 = 0x80102004
 *
 * A U-mode load from 0x80102000:
 *   correct: outside every granted region -> load access fault (mcause 5) -> PASS
 *   buggy:   inside entry1 (< 0x80102004) -> load succeeds; we then ecall
 *            (mcause 8) and FAIL.
 */

#define TEST_ADDR 0x80102000

  .section .text
  .globl test_main
test_main:
  /* entry0: TOR boundary 0x80100000 (0x80100000 >> 2 = 0x20040000) */
  li    t0, 0x20040000
  csrw  pmpaddr0, t0

  /* entry1: TOR boundary 0x80102000 with low bit set (0x20040800 | 1) */
  li    t0, 0x20040801
  csrw  pmpaddr1, t0

  /* pmpcfg0 holds cfg0 (byte 0) and cfg1 (byte 1): both TOR | R | W | X = 0x0F */
  li    t0, 0x0F0F
  csrw  pmpcfg0, t0

  ENTER_MODE(0, u_code)

  .align 2
u_code:
  li    t0, TEST_ADDR
  lw    t1, 0(t0)     /* correct core traps here (load access fault) */
  ecall              /* buggy core reaches here (load allowed) */
1:j 1b

  .globl trap_handler
  .align 2
trap_handler:
  csrr  t6, mcause
  li    t5, 5        /* load access fault -> correct core */
  beq   t6, t5, _pass
  li    t5, 8        /* ecall from U-mode -> buggy core (load succeeded) */
  beq   t6, t5, _buggy
  FAIL(100)          /* anything else is unexpected */
_pass:
  PASS
_buggy:
  FAIL(1)
