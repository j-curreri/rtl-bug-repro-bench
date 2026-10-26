#include "test.h"

/* hgatp is a WARL register: bits 59:58 are not part of MODE, VMID or PPN and must
 * read back as zero. The buggy core stores them, so the readback keeps them. */
  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  li t0, 0x8C00000000000000   /* MODE = Sv39x4 (8), bits 59:58 set */
  csrw hgatp, t0
  csrr t1, hgatp
  li t2, 0x8000000000000000   /* expected readback: bits 59:58 cleared */
  bne t1, t2, 1f
  PASS
1: FAIL(1)
