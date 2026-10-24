#include "test.h"

/*
 * Reproducer for the CVA6 hgatp WARL bug.
 *
 * Bug: writing hgatp with an unsupported MODE value is ignored entirely
 * (no field changes).  Per the hypervisor spec this is NOT the satp rule:
 * the hgatp fields are WARL in the normal way, so PPN and VMID must be
 * updated to the written values (and MODE must become a legal value).
 *
 * CVA6 hgatp layout (XLEN=64):
 *   [63:60] MODE   (4 bits)
 *   [59:58] WARL0  (2 bits, zero)
 *   [57:44] VMID   (14 bits)
 *   [43:0]  PPN    (44 bits, bits[1:0] hardwired 0)
 * This core only supports MODE = 0 (Off) and 8 (Sv39); every other value is
 * "unsupported".
 *
 * Test:
 *   1. write hgatp = {MODE=Sv39, VMID=V0, PPN=P0}  (supported -> sticks on both)
 *   2. write hgatp = {MODE=BAD,  VMID=V1, PPN=P1}  (unsupported)
 *   3. read back:
 *        correct core: PPN==P1 and VMID==V1   -> PASS
 *        buggy core:   PPN==P0 and VMID==V0   -> FAIL
 */

  .equ P0, 0xA000
  .equ P1, 0xB000
  .equ V0, 0x0001
  .equ V1, 0x0002
  .equ MODE_SV39, 8
  .equ MODE_BAD,  1        /* unsupported */

  .globl test_main
  .align 2
test_main:
  PMP_ALLOW_ALL

  /* --- step 1: supported mode so PPN/VMID definitely stick; sanity check --- */
  li t0, ((MODE_SV39 << 60) | (V0 << 44) | P0)
  csrw hgatp, t0
  csrr t1, hgatp

  li t2, -1
  srli t2, t2, 20          /* 44 ones = PPN mask */
  and  t3, t1, t2          /* PPN read back */
  li t4, P0
  bne  t3, t4, fail

  li t5, 0x3FFF
  srli t6, t1, 44
  and  t6, t6, t5          /* VMID read back */
  li t5, V0
  bne  t6, t5, fail

  /* --- step 2: write an UNSUPPORTED MODE with new PPN/VMID --- */
  li t0, ((MODE_BAD << 60) | (V1 << 44) | P1)
  csrw hgatp, t0
  csrr t1, hgatp

  /* PPN must now be P1 (buggy core keeps P0) */
  li t2, -1
  srli t2, t2, 20
  and  t3, t1, t2
  li t4, P1
  bne  t3, t4, fail

  /* VMID must now be V1 (buggy core keeps V0) */
  li t5, 0x3FFF
  srli t6, t1, 44
  and  t6, t6, t5
  li t5, V1
  bne  t6, t5, fail

  PASS

fail:
  FAIL(2)
