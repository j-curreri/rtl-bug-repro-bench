#include "test.h"

/*
 * Bug reproducer: NAPOT (match=1) address-match triggers (Sdtrig / mcontrol6)
 * fail to fire for accesses inside the configured naturally-aligned range,
 * while exact-match (match=0) triggers work.
 *
 * Root cause (core/include/triggers_pkg.sv, napot_match64):
 *   is_valid_napot = ((base & (base + 1)) == 0);
 * only accepts trigger addresses of the form 2^k - 1 (i.e. NAPOT regions that
 * start at address 0). Any valid NAPOT encoding whose upper address bits are
 * non-zero (a region at a non-zero address) is rejected, so the trigger never
 * fires for accesses inside its configured range.
 *
 * Test strategy:
 *   - Program trigger 0 as an mcontrol6 LOAD-ADDRESS trigger, M-mode,
 *     action = breakpoint, match = NAPOT, targeting the 4-byte range
 *     [sp, sp+3]  (tdata2 = sp | 3, sp is 16-byte aligned).
 *   - Perform a single load from sp. It is the only access to that range.
 *       * correct core: the load-address trigger fires -> breakpoint
 *         exception (mcause = 3, mtval = sp) -> trap handler -> PASS
 *       * buggy core:   napot_match64 rejects the trigger value, no trigger
 *         fires, the load completes normally -> explicit FAIL
 */

  .section .text
  .align 2
  .globl test_main
test_main:
  addi sp, sp, -32             /* 16-byte aligned frame; [sp, sp+3] is 4-byte aligned */

  /* tselect = 0 (default after reset, set explicitly anyway) */
  li   t0, 0
  csrw tselect, t0

  /* tdata1: type = 6 (mcontrol6)
   *   bits [63:60] = 0000 0110  (type)
   *   bit   21     = 0          (select: match on address, not data)
   *   bits [10:7]  = 0001      (match = 1 -> NAPOT)
   *   bit    6     = 1          (m: trigger in M-mode)
   *   bit    0     = 1          (load: trigger on load address)
   *   bits [15:12] = 0000      (action = 0 -> breakpoint)
   */
  li   t0, 0x60000000000000C1
  csrw tdata1, t0

  /* tdata2 = sp | 3 : NAPOT encoding of the 4-byte region [sp, sp+3] */
  addi t0, sp, 3
  csrw tdata2, t0

  /* Sanity: the trigger CSRs must have been programmed as intended. */
  csrr t0, tdata1
  li   t1, 0x60000000000000C1
  bne  t0, t1, bad_tdata1
  csrr t0, tdata2
  addi t1, sp, 3
  bne  t0, t1, bad_tdata2

  /* Tripwire: the only load in the NAPOT region. A spec-compliant core must
   * fire the trigger and trap here before the load completes. */
  lw   t1, 0(sp)

  /* Reached only if the NAPOT trigger failed to fire. */
  FAIL(1)

bad_tdata1:
  FAIL(4)
bad_tdata2:
  FAIL(5)

/* M-mode trap handler: verify the breakpoint came from our tripwire load. */
  .align 2
  .globl trap_handler
trap_handler:
  csrr t3, mcause
  li   t4, 3                  /* expected cause: breakpoint */
  bne  t3, t4, wrong_cause
  csrr t3, mtval
  bne  t3, sp, wrong_tval     /* expected tval: address of the tripwire load */
  PASS
wrong_cause:
  FAIL(2)
wrong_tval:
  FAIL(3)
