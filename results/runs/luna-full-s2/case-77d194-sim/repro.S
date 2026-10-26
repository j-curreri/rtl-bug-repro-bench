#include "test.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  /* Learn the WARL readback for one legal Sv39x4 hgatp value. */
  li t0, 0x8000100000080000
  csrw hgatp, t0
  csrr s0, hgatp
  slli s0, s0, 4
  srli s0, s0, 4             /* Keep VMID and PPN, discard MODE. */

  /* Install a different legal value so an ignored write is observable. */
  li t0, 0x8000200000081000
  csrw hgatp, t0
  csrr s1, hgatp
  slli s1, s1, 4
  srli s1, s1, 4
  beq s1, s0, 2f

  /* MODE=1 is reserved and unsupported by this Sv39x4 implementation.
     The other fields are WARL independently and must still be written. */
  li t0, 0x1000100000080000
  csrw hgatp, t0
  nop
  nop
  nop
  nop
  nop
  csrr t1, hgatp
  slli t1, t1, 4
  srli t1, t1, 4
  bne t1, s0, 1f

  PASS
1:
  FAIL(1)
2:
  FAIL(2)

  .globl trap_handler
  .align 2
trap_handler:
  FAIL(127)
