#include "test.h"

/* Writing hgatp with an unsupported MODE must leave MODE unchanged (WARL) but still
 * update the other fields (VMID, PPN). This core drops the whole write instead. */
  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Reset value of hgatp is 0 (Bare). Write MODE=9 (Sv48x4, unsupported),
   * VMID=5 (bits 57:44), PPN=0x12344 (bits 43:0). */
  li t0, (9 << 60) | (5 << 44) | 0x12344
  csrw hgatp, t0

  csrr t1, hgatp

  /* Expected on a correct core: MODE=0, VMID=5, PPN=0x12344. */
  li t2, (5 << 44) | 0x12344
  bne t1, t2, 1f
  PASS
1:
  FAIL(1)
