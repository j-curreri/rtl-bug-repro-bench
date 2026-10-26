#include "hyp.h"

  .section .text
  .globl test_main
test_main:
  /* Start with a legal Sv39x4 value so MODE has a supported prior value. */
  la t0, g_root
  srli t0, t0, 12
  li t1, 8
  slli t1, t1, 60
  or t0, t0, t1
  csrw hgatp, t0

  /* MODE=1 is unsupported. VMID and PPN are still WARL independently. */
  la t3, vs_root
  srli t3, t3, 12
  mv t0, t3
  li t1, 1
  slli t1, t1, 44
  or t0, t0, t1
  li t1, 1
  slli t1, t1, 60
  or t0, t0, t1
  csrw hgatp, t0

  csrr t2, hgatp

  /* PPN[43:0] must reflect the second write. */
  li t4, -1
  srli t4, t4, 20
  and t5, t2, t4
  bne t5, t3, fail_ppn

  /* The selected VMID bit must also reflect the second write. */
  srli t5, t2, 44
  andi t5, t5, 1
  li t6, 1
  bne t5, t6, fail_vmid

  PASS

fail_ppn:
  FAIL(1)
fail_vmid:
  FAIL(2)

  HYP_TABLES
