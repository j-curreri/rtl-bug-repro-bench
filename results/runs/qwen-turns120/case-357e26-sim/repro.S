/* Bug reproducer: PMP TOR boundary with pmpaddr LSB set (8-byte PMP granularity, G=1).
 *
 * This core implements PMP with an 8-byte granularity (G=1): a pmpaddr value
 * encodes PA bits [PA-1:2], and the LSB of pmpaddr (PA bit 2) is WARL — in
 * TOR mode it is read back as 0, so a TOR boundary is always 8-byte aligned.
 * The PMP check must therefore use the 8-byte-aligned boundary
 * (pmpaddr & ~1) << 2. The buggy core instead uses the raw pmpaddr value
 * (pmpaddr << 2), so a TOR entry whose pmpaddr has its lowest bit set
 * protects 4 bytes beyond the expected range and accesses at the true
 * 8-byte-aligned boundary are checked against the wrong (previous) entry.
 *
 * Setup (M-mode):
 *   pmpcfg0  = 0x0f09: entry 0 = TOR + R-only, entry 1 = TOR + RWX
 *                      (pmpcfg layout: bit7=L, [4:3]=A, bit2=X, bit1=W, bit0=R)
 *   pmpaddr0 = 0x20000001  (lowest bit set)
 *   pmpaddr1 = -1
 *
 * Resulting TOR regions:
 *   correct core: entry 0 = [0, 0x80000000), entry 1 = [0x80000000, ...)
 *   buggy core:   entry 0 = [0, 0x80000004), entry 1 = [0x80000004, ...)
 *
 * Test: U-mode store to 0x80000000 (the 8-byte-aligned region boundary).
 *   correct core: no match in entry 0, matches entry 1 (RWX)  -> store ok,
 *                 then ecall -> mcause 8 -> PASS
 *   buggy core:   matches entry 0 (R-only) -> store access fault (mcause 7)
 *                 -> FAIL
 */
#include "test.h"

  .section .text
  .balign 4
  .globl test_main
test_main:
  /* Remember the byte at 0x80000000 (first byte of .text.init) so the U-mode
   * store can leave memory unchanged. M-mode accesses bypass PMP. */
  li t1, 0x80000000
  lb t2, 0(t1)

  /* Configure PMP before the addresses: entry 0 = TOR+R, entry 1 = TOR+RWX.
   * pmpcfg0 bytes: [0]=entry0, [1]=entry1, [2..3]=OFF. */
  li t0, 0x0f09
  csrw pmpcfg0, t0
  /* Odd pmpaddr0 (LSB set): boundary 0x80000000 on a correct core,
   * 0x80000004 on the buggy core. */
  li t0, 0x20000001
  csrw pmpaddr0, t0
  li t0, -1
  csrw pmpaddr1, t0

  ENTER_MODE(0, u_store)

u_store:
  .align 2
  /* U-mode store at the region boundary.
   * Correct core: entry 1 (RWX) -> allowed.
   * Buggy core:   entry 0 (R-only) -> store access fault. */
  sb t2, 0(t1)
  ecall                    /* return to M-mode; trap_handler -> PASS */
  wfi                      /* unreachable */

/* Custom trap handler: only the U-mode ecall (mcause 8) means the test
 * store succeeded -> PASS. Any other trap is reported as a failure. */
  .balign 4
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  andi t6, t6, 0x3f
  li t5, 8
  beq t6, t5, 1f
  /* Unexpected trap: tohost = ((mcause + 2) << 1) | 1 (never 1 = PASS). */
  addi a0, t6, 2
  slli a0, a0, 1
  ori a0, a0, 1
  j _halt
1:
  PASS
