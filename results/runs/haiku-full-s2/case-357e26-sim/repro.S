#include "test.h"

/* PMP G=1 (8-byte grain): in TOR mode the low bit of pmpaddr is not part of the
 * region bound, so an odd pmpaddr Q bounds the region at (Q & ~1) << 2.
 *
 * Layout:
 *   entry 0: NAPOT 64 KiB at 0x80000000, RWX (code, data, stack; must not cover the probe)
 *   entry 1: OFF, pmpaddr1 = L>>2 = 0x80010000 >> 2  (lower bound of entry 2)
 *   entry 2: TOR RWX, pmpaddr2 = Q = 0x20004005 (odd)
 *
 * Correct region is [0x80010000, 0x80010010). The address A = 0x80010010 is outside it,
 * so a U-mode load of A must raise a load access fault (mcause 5).
 * The buggy core uses bound Q<<2 = 0x80010014 and lets the load through. */

#define PMP_L_ADDR  0x20004000
#define PMP_Q_ADDR  0x20004005
#define PROBE_ADDR  0x80010010

  .section .text
  .globl test_main
test_main:
  li t0, 0x20001fff          /* entry 0: NAPOT 64 KiB at 0x80000000 */
  csrw pmpaddr0, t0
  li t0, PMP_L_ADDR          /* entry 1: OFF, lower bound of entry 2 */
  csrw pmpaddr1, t0
  li t0, PMP_Q_ADDR          /* entry 2: TOR, odd upper bound */
  csrw pmpaddr2, t0
  li t0, 0x000f001f          /* cfg0: entry0 NAPOT RWX, entry1 OFF, entry2 TOR RWX */
  csrw pmpcfg0, t0

  ENTER_MODE(0, umode)

umode:
  li t1, PROBE_ADDR
  lw t2, 0(t1)               /* must fault on the correct core */
  li a0, 2                   /* only reached if the load succeeded (buggy core) */
  ecall                      /* U-mode ecall: handled as FAIL */

  .globl trap_handler
  .align 2
trap_handler:
  csrr t6, mcause
  li t5, 5                   /* load access fault: the expected outcome */
  beq t6, t5, 1f
  FAIL(1)
1:
  PASS
