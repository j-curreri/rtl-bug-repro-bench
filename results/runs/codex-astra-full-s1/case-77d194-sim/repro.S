#include "test.h"

  .section .text
  .balign 4
  .globl test_main
test_main:
  /* Stay in M-mode: hgatp cannot translate any of our accesses.  Establish
   * Sv39x4, VMID=0, PPN=0x80000 (a 16-KiB-aligned root in DRAM).
   * No page-table walk is needed for this CSR-only test.
   */
  li t0, 0x8000000000080000
  csrw hgatp, t0
  csrr t1, hgatp
  bne t1, t0, setup_failed

  /* MODE=15 is unsupported.  Unlike satp, hgatp must still update its
   * other WARL fields.  Zero is legal for both VMID and PPN, including
   * when the implementation legalizes MODE to Bare.
   */
  li t0, 0xf000000000000000
  csrw hgatp, t0
  csrr t1, hgatp

  /* Discard MODE: its particular legal readback value is not prescribed.
   * All remaining fields were written as zero and must read as zero.
   * The buggy core retains PPN=0x80000, so this branch detects it.
   */
  slli t1, t1, 4
  bnez t1, fields_not_updated

  csrw hgatp, zero
  PASS

setup_failed:
  FAIL(1)
fields_not_updated:
  FAIL(2)

  .balign 4
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  FAIL(3)
