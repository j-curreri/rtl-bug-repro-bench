#include "test.h"

/* Sdtrig mcontrol6 with match=1 (NAPOT) on execute-address. tdata2 = target | 3 names a
 * naturally aligned power-of-two region (at least 4 bytes) that contains the 8-byte aligned
 * `target`, so the breakpoint must fire on fetch of `target`. The buggy napot_match64 rejects
 * this encoding (its validity test only accepts all-ones bases), so no trap occurs and the
 * program falls through to FAIL(1). */

  .section .text
  .globl test_main
  .globl trap_handler

  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 3                /* breakpoint */
  bne t0, t1, 1f
  la t1, target
  csrr t2, mepc
  bne t1, t2, 2f
  PASS
1: FAIL(2)                /* unexpected cause */
2: FAIL(3)                /* wrong mepc */

  .align 2
test_main:
  PMP_ALLOW_ALL

  /* tselect = 0 */
  csrw 0x7a0, zero

  /* tdata2 = target | 3 : NAPOT region containing target */
  la t0, target
  ori t0, t0, 3
  csrw 0x7a2, t0

  /* tdata1 (RV64): type=6 in [63:60], m=1, match=1 (NAPOT), action=0 (breakpoint), execute=1 */
  li t0, 6
  slli t0, t0, 60
  ori t0, t0, ((1 << 7) | (1 << 6) | (1 << 2))
  csrw 0x7a1, t0

  .balign 8
target:
  nop
  FAIL(1)
