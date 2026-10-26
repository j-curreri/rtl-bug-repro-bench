#include "test.h"

  .section .text
  .balign 4
  .globl test_main
test_main:
  /* Establish that these PPN/VMID values are legal on this implementation.
   * PPN[1:0] is zero, as required for an Sv39x4 root's 16 KiB alignment.
   * No guest runs, so the root does not need to contain page-table entries.
   */
  li t0, ((8 << 60) | (1 << 44) | 0x80004)
  csrw hgatp, t0
  csrr s0, hgatp
  slli s0, s0, 4                 /* Discard MODE; retain the other fields. */
  srli s0, s0, 4
  li t1, ((1 << 44) | 0x80004)
  bne s0, t1, setup_failed

  /* Give the old value different PPN and VMID fields. */
  li t0, ((8 << 60) | 0x80000)
  csrw hgatp, t0
  csrr t1, hgatp
  slli t1, t1, 4
  srli t1, t1, 4
  li t2, 0x80000
  bne t1, t2, setup_failed

  /* MODE=1 is reserved/unsupported. Unlike satp, an unsupported hgatp
   * MODE must not suppress writes to its other WARL fields. Allow any
   * legal MODE readback; check only the previously verified PPN/VMID.
   */
  li t0, ((1 << 60) | (1 << 44) | 0x80004)
  csrw hgatp, t0
  csrr t1, hgatp
  slli t1, t1, 4
  srli t1, t1, 4
  bne t1, s0, update_failed

  csrw hgatp, zero
  PASS

setup_failed:
  FAIL(2)
update_failed:
  FAIL(1)

  .balign 4
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  FAIL(127)
