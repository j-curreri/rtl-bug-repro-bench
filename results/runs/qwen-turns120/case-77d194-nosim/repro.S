/* Reproducer for the CVA6 hgatp WARL bug (bug report: writing hgatp with an
 * unsupported MODE value is ignored entirely).
 *
 * Spec behaviour (RISC-V H extension, hgatp register): the PPN and VMID fields
 * of hgatp are WARL in the normal way.  Unlike satp, a write of an unsupported
 * MODE value is NOT ignored as a whole: PPN and VMID are still written, and
 * only the MODE field is left unchanged.  The buggy core drops the entire
 * write instead.
 *
 * Test (entirely in M-mode, where hgatp is freely readable/writable and no
 * translation takes place, so no trap can occur):
 *   1. Put hgatp in a known valid state: MODE=Sv39x4(8), PPN=0, VMID=0 and
 *      verify the readback (a valid write must work on any core).
 *   2. Write hgatp with an unsupported MODE value (9 = Sv48x4, then 13 =
 *      future) together with distinct PPN and VMID values.  PPN values are
 *      multiples of 8 (PPN[2:0]=0, the 16 KiB G-stage root alignment), so the
 *      expected readback is identical on any conforming implementation.
 *   3. Read hgatp back and verify PPN[8:0] (register bits 43:35) and VMID
 *      (register bits 57:44) equal the values just written.
 *      - correct core: PPN/VMID updated  -> PASS
 *      - buggy core:   whole write ignored, PPN/VMID unchanged -> FAIL
 */
#include "test.h"

  .globl test_main
test_main:
  /* ---- step 1: known-valid state ------------------------------------- */
  li   t0, (8 << 60)             /* MODE=Sv39x4, PPN=0, VMID=0 */
  csrw hgatp, t0
  csrr t0, hgatp
  li   t1, (8 << 60)
  bne  t0, t1, 1f
  j    2f
1: FAIL(1)

  /* ---- step 2: unsupported MODE must still update PPN and VMID ------- */
2:
  /* case A: MODE=9 (Sv48x4), PPN=0x150, VMID=5 */
  li   t0, (9 << 60)
  li   t1, 0x150
  sll  t1, t1, 35
  or   t0, t0, t1
  li   t1, 5
  sll  t1, t1, 44
  or   t0, t0, t1
  csrw hgatp, t0
  csrr t0, hgatp
  srli t1, t0, 35                /* PPN[8:0] = bits 43:35 */
  li   t2, 0x1ff
  and  t1, t1, t2
  li   t3, 0x150
  bne  t1, t3, 3f
  srli t1, t0, 44                /* VMID = bits 57:44 */
  li   t2, 0x3fff
  and  t1, t1, t2
  li   t3, 5
  bne  t1, t3, 3f

  /* case B: MODE=13 (future), PPN=0x1a8, VMID=0x5c */
  li   t0, (13 << 60)
  li   t1, 0x1a8
  sll  t1, t1, 35
  or   t0, t0, t1
  li   t1, 0x5c
  sll  t1, t1, 44
  or   t0, t0, t1
  csrw hgatp, t0
  csrr t0, hgatp
  srli t1, t0, 35
  li   t2, 0x1ff
  and  t1, t1, t2
  li   t3, 0x1a8
  bne  t1, t3, 3f
  srli t1, t0, 44
  li   t2, 0x3fff
  and  t1, t1, t2
  li   t3, 0x5c
  bne  t1, t3, 3f

  PASS
3: FAIL(2)
