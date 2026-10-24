/*
 * Bug reproducer: writing hgatp with an unsupported G-stage MODE value is
 * ignored entirely (no field of the register is updated).
 *
 * Per the RISC-V hypervisor spec such a write must NOT be ignored the way an
 * unsupported-MODE write to satp is: the fields of hgatp are WARL in the
 * normal way, so PPN/VMID etc. are still updated when an unsupported MODE
 * value is written.
 *
 * Test, entirely in M-mode, no memory accesses:
 *   1. hgatp := 0 (MODE=0/Bare); check readback.
 *   2. hgatp := W1 = {MODE=8, VMID=0x2A5, PPN=0x12340000}.  MODE=8 (Sv39x4)
 *      is the only non-Bare G-stage mode this core supports, so W1 must
 *      stick on every implementation.
 *   3. hgatp := W2 = {MODE=9, VMID=0x55A, PPN=0x43210000}.  MODE=9 is not
 *      supported by this core.
 *   4. Read back hgatp:
 *        - correct core: the write was applied WARL (at least PPN/VMID
 *          changed) -> register differs from W1 -> PASS
 *        - buggy core:  the write was ignored -> readback is still W1 -> FAIL
 *
 * hgatp bit layout (XLEN=64, cf. hgatp_t in core/csr_regfile.sv):
 *   [63:60] MODE, [59:58] reserved, [57:44] VMID, [43:0] PPN
 */
#include "test.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* 1. Known initial state: MODE=0 (Bare) */
  csrw hgatp, zero
  csrr t0, hgatp
  bnez t0, 1f
  j step2
1:  FAIL(1)

  /* 2. Write a supported G-stage mode value (Sv39x4 = 8 in this core's
   *    mode encoding) and check that it sticks (sanity check shared by the
   *    buggy and the correct core). */
step2:
  li t1, (8 << 60) | (0x2A5 << 44) | 0x12340000
  csrw hgatp, t1
  csrr t0, hgatp
  beq t0, t1, step3
  FAIL(2)

  /* 3. Write an unsupported G-stage MODE (9) together with a different PPN
   *    and VMID.  On a correct core the register changes (fields are
   *    updated in the usual WARL way); on the buggy core the whole write
   *    is ignored. */
step3:
  li t2, (9 << 60) | (0x55A << 44) | 0x43210000
  csrw hgatp, t2
  csrr t0, hgatp

  /* 4. t1 still holds W1 */
  bne t0, t1, pass_lbl
  FAIL(3)
pass_lbl:
  PASS
