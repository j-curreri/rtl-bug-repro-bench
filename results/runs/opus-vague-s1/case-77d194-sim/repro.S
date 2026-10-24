/* Reproducer: hgatp bits 59:58 are a reserved "0" field in RV64 (MODE[63:60],
 * 0[59:58], VMID[57:44], PPN[43:0]) and must always read as zero.  The buggy
 * core stores whatever is written there. */
#include "hyp.h"

#define HGATP_RSVD (3 << 58)

.text
.global test_main
test_main:
  csrw hgatp, zero

  /* Bare mode, reserved bits set together with VMID/PPN bits */
  li t0, HGATP_RSVD | (1 << 44) | 0x1000
  csrw hgatp, t0
  csrr t1, hgatp
  li t2, HGATP_RSVD
  and t3, t1, t2
  bnez t3, fail1

  /* Sv39x4 mode, reserved bits set */
  li t0, SATP_SV39 | HGATP_RSVD | 0x1000
  csrw hgatp, t0
  csrr t1, hgatp
  li t2, HGATP_RSVD
  and t3, t1, t2
  bnez t3, fail2

  /* csrs of only the reserved bits must not make them stick either */
  csrw hgatp, zero
  li t0, HGATP_RSVD
  csrs hgatp, t0
  csrr t1, hgatp
  bnez t1, fail3

  csrw hgatp, zero
  PASS
fail1: FAIL(1)
fail2: FAIL(2)
fail3: FAIL(3)
