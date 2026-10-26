#include "hyp.h"

  .text
  .globl test_main
test_main:
  /* Compute two distinct 16-KiB-aligned PPNs in DRAM (PPN[1:0] == 0). */
  la s0, g_table_a
  srli s0, s0, 12
  la s1, g_table_b
  srli s1, s1, 12

  /* Mask for non-MODE fields of hgatp: bits [59:0]. */
  li s4, -1
  srli s4, s4, 4

  /* Probe legal WARL values of (VMID, PPN) using supported MODE = Bare (0). */
  li t0, 1
  slli t0, t0, 44
  or t0, t0, s0
  csrw hgatp, t0
  csrr s2, hgatp
  and s2, s2, s4
  beqz s2, fail_prep

  li t0, 2
  slli t0, t0, 44
  or t0, t0, s1
  csrw hgatp, t0
  csrr s3, hgatp
  and s3, s3, s4
  beq s2, s3, fail_prep

  /* Test 1: From hgatp = 0 (Bare), write unsupported MODE = 9 (Sv48x4)
   * along with legal VMID=1 and PPN=ppn_a.
   * Per RISC-V Hypervisor spec, writes to hgatp with an unsupported MODE are
   * NOT ignored; VMID and PPN are WARL in the normal way and must update. */
  csrw hgatp, zero
  li t0, 9
  slli t0, t0, 60
  or t0, t0, s2
  csrw hgatp, t0
  csrr t1, hgatp
  and t2, t1, s4
  bne t2, s2, fail_test1

  /* Test 2: From hgatp in supported MODE = 8 (Sv39x4) with (VMID=1, PPN=ppn_a),
   * write unsupported MODE = 10 (Sv57x4) with (VMID=2, PPN=ppn_b).
   * Again, VMID and PPN must update to (VMID=2, PPN=ppn_b). */
  li t0, 8
  slli t0, t0, 60
  or t0, t0, s2
  csrw hgatp, t0

  li t0, 10
  slli t0, t0, 60
  or t0, t0, s3
  csrw hgatp, t0
  csrr t1, hgatp
  and t2, t1, s4
  bne t2, s3, fail_test2

  csrw hgatp, zero
  PASS

fail_prep:
  FAIL(1)
fail_test1:
  FAIL(2)
fail_test2:
  FAIL(3)

  .data
  .align 14
g_table_a:
  .space 16384
  .align 14
g_table_b:
  .space 16384
