#include "test.h"

  .section .text
  .balign 4
  .globl test_main
test_main:
  /* Stay in M-mode: no G-stage translations or page tables are needed.
   * Sv39x4 with PPN 0x80000 names a 16-KiB-aligned DRAM address.
   */
  li t0, 0x8000000000080000
  csrw hgatp, t0
  csrr t1, hgatp
  slli t1, t1, 4
  beqz t1, setup_failed

  /* MODE=15 is reserved. Unlike satp, hgatp must apply normal WARL
   * behavior to its fields rather than discard the entire write.
   * PPN=0 and VMID=0 are legal regardless of the resulting MODE,
   * including an implementation that forces all Bare fields to zero.
   */
  li t0, 0xf000000000000000
  csrw hgatp, t0
  csrr t1, hgatp

  /* Ignore the WARL choice of MODE; all remaining bits must be zero.
   * Buggy RTL retains the nonzero PPN from the first write.
   */
  slli t1, t1, 4
  bnez t1, write_ignored

  csrw hgatp, zero
  PASS

write_ignored:
  FAIL(1)
setup_failed:
  FAIL(2)

  .balign 4
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  FAIL(3)
