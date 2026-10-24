/* repro.S - Bug reproducer: Sdtrig mcontrol6 NAPOT (match=1) address triggers
 * never fire for accesses inside the configured naturally aligned range.
 *
 * Root cause (core/include/triggers_pkg.sv, napot_match64/napot_match32):
 *
 *     is_valid_napot = ((base & (base + 1)) == 0);
 *
 * For any NAPOT base with non-zero upper bits (i.e. every practical memory
 * region such as DRAM at 0x80000000), `base` and `base + 1` share those upper
 * bits, so `base & (base + 1)` is non-zero and the function declares the base
 * "invalid" and returns 0 - the trigger can never match.  Only bases of the
 * form 2^k - 1 (regions anchored at address 0) survive the check.  Exact
 * match (match=0) uses a plain equality test and is unaffected.
 *
 * This program configures trigger 0 as mcontrol6 (type 6) with:
 *   - match   = 1 (NAPOT)
 *   - m       = 1   (M-mode only; the test runs in M-mode)
 *   - store   = 1   (address match on stores)
 *   - action  = 0   (breakpoint exception)
 *   - tdata2  = the NAPOT encoding of the 4 KiB page immediately after the
 *               program image (the first page past _end).  A store to the
 *               start of that page is inside the configured range.
 *
 * A store to an address inside the NAPOT range must therefore raise a
 * breakpoint exception (mcause = 3, mepc = PC of the store) on a
 * spec-conformant core.
 *
 *  - Correct core: the trap is taken; the handler verifies mcause/mepc,
 *    disables the trigger, sets a flag and mrets; the test then prints PASS.
 *  - Buggy core:   the NAPOT trigger never fires, the store completes, no
 *    trap is taken and the test prints FAIL(1).
 */

#include "test.h"

  /* Trigger CSR numbers as implemented by this core's CSR regfile
   * (Sdtrig spec values, see core/include/riscv_pkg.sv):
   * tselect = 0x7a0, tdata1 = 0x7a1, tdata2 = 0x7a2.
   * Written as decimal so no -march extension is required. */
  #define CSR_TSELECT  1952  /* 0x7a0 */
  #define CSR_TDATA1   1953  /* 0x7a1 */
  #define CSR_TDATA2   1954  /* 0x7a2 */

  /* mcontrol6 tdata1 low-part for the armed trigger:
   * match=1 NAPOT (bit 7), m=1 (bit 6), store=1 (bit 1)  -> 0xc2 */
  #define MC6_NAPOT_M_STORE   0xc2

  .section .data
  .align 3
  trap_flag:     .dword 0        /* set to 1 by trap_handler on the expected trap */
  expected_mepc: .dword 0        /* PC of the store that must trigger the trap */

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* remember the PC of the store instruction that must raise the trap */
  la   t0, trigger_target
  la   t1, expected_mepc
  sd   t0, 0(t1)

  /* Compute the 4 KiB NAPOT region: the first page past the program image.
   *   t2 = P          = region start  = (_end + 0xfff) & ~0xfff
   *   t4 = tdata2     = P | 0xfff     (NAPOT encoding of the page [P, P+0xfff]) */
  la   t2, _end
  li   t5, 0xfff
  add  t2, t2, t5
  not  t5, t5
  and  t2, t2, t5          /* t2 = P (4K-aligned, past the program) */
  li   t4, 0xfff
  add  t4, t2, t4          /* t4 = tdata2 = P + 0xfff */

  /* ---- arm trigger 0 -------------------------------------------- */
  li   t0, 0
  csrw CSR_TSELECT, t0

  li   t3, 6
  slli t3, t3, 60            /* tdata1[63:60] = 6: mcontrol6 */
  ori  t3, t3, MC6_NAPOT_M_STORE
  csrw CSR_TDATA1, t3

  csrw CSR_TDATA2, t4        /* tdata2 = P | 0xfff */

  /* ---- fire the trigger ------------------------------------------ */
trigger_target:
  sd   zero, 0(t2)           /* store to P, inside the NAPOT range: a conformant
                                 core must take a breakpoint here */

  /* Reached without a trap: the NAPOT trigger failed to fire. */
  la   t0, trap_flag
  ld   t0, 0(t0)
  li   t1, 1
  beq  t0, t1, pass
  FAIL(1)

pass:
  PASS

  .align 2
  .globl trap_handler
trap_handler:
  csrr t5, mcause
  li   t0, 3                 /* BREAKPOINT */
  beq  t5, t0, th_cause_ok
  FAIL(128)

th_cause_ok:
  csrr t5, mepc

  /* Disable the trigger before touching any memory: rewrite tdata1 as
   * mcontrol6 with m=s=u=0 and no store/load/execute enable. */
  li   t1, 6
  slli t1, t1, 60
  csrw CSR_TDATA1, t1

  /* the trap must be at the PC of the triggered store */
  la   t0, expected_mepc
  ld   t0, 0(t0)
  beq  t5, t0, th_mepc_ok
  FAIL(129)

th_mepc_ok:
  /* Record the expected trap, then resume the aborted store. */
  la   t1, trap_flag
  li   t2, 1
  sd   t2, 0(t1)
  mret
