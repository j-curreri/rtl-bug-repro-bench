#include "test.h"

/*
 * PMP TOR grain bug (G=1, 8-byte grain).
 *
 * This core keeps the lowest bit of a pmpaddr value when it uses the entry in
 * TOR matching, instead of forcing it to 0 as required for a grain of G=1.
 * A pmpaddr written with its lowest bit set therefore pushes the TOR upper
 * boundary 4 bytes too high, so a U-mode access exactly at the intended
 * boundary is checked against the wrong (lower-index) entry.
 *
 * Layout (all TOR, boundaries are (pmpaddr << 2)):
 *   entry0: [0x00000000, 0x80018000)  RWX   covers the test code + stack
 *   entry1: [0x80018000, B)           R     boundary B, pmpaddr1 lowest bit = 1
 *   entry2: [B,          0x80040000)  RWX
 * with B = 0x80020000.
 *
 * Correct core: pmpaddr1 low bit treated as 0 -> entry1 boundary = B, so a
 * store to B is not in entry1; it matches entry2 (RWX) and succeeds.
 * Buggy core:   entry1 boundary = B + 4, so a store to B matches entry1 (R
 * only) first and faults.
 *
 * U-mode stores a byte to B, then ecalls. The M-mode handler turns the ecall
 * into PASS and a store access fault into FAIL.
 */

  .section .text
  .globl test_main
test_main:
  /* entry0 boundary: 0x80018000 >> 2 */
  li   t0, 0x20006000
  csrw pmpaddr0, t0
  /* entry1 boundary: (0x80020000 >> 2) with lowest bit set */
  li   t0, 0x20008001
  csrw pmpaddr1, t0
  /* entry2 boundary: 0x80040000 >> 2 */
  li   t0, 0x20010000
  csrw pmpaddr2, t0
  /* pmpcfg0: byte0=0x0F (TOR,RWX) byte1=0x09 (TOR,R) byte2=0x0F (TOR,RWX) */
  li   t0, 0x000F090F
  csrw pmpcfg0, t0

  ENTER_MODE(0, user_code)

user_code:
  li   t1, 0x80020000        /* B, the intended TOR boundary */
  sb   x0, 0(t1)             /* correct: allowed (entry2); buggy: fault (entry1) */
  ecall                      /* reached only on a correct core */

  .globl trap_handler
  .align 2
trap_handler:
  csrr t6, mcause
  li   t5, 8                 /* environment call from U-mode */
  beq  t6, t5, 1f
  li   t5, 7                 /* store/AMO access fault */
  beq  t6, t5, 2f
  FAIL(127)
1:
  PASS
2:
  FAIL(1)
