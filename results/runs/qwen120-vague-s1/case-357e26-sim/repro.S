/*
 * Bug reproducer: PMP does not always protect the address range that software
 * configured.
 *
 * The CVA6 PMP NAPOT decoder computes the region size as
 *     size = trail_ones + 3
 * and uses  mask = '1 << size   (it ignores the low `size` address bits when
 * matching).  For a NAPOT entry whose pmpaddr has `n` trailing ones, the
 * RISC-V specification defines the region as 2^(n+2) bytes, i.e. the mask
 * should ignore only `n+2` low bits.  This core therefore matches a region that
 * is 2x too large: it covers the *intended* range plus an extra half of the
 * same size directly above it.
 *
 * Concretely, a NAPOT entry configured to cover [B, B+S-1] actually covers
 * [B, B+2*S-1] on this core.
 *
 * Strategy
 * --------
 *  - PMP entry 0: TOR [0, BOUND)  RWX  -> lets S-mode run the test code.
 *  - PMP entry 1: NAPOT, intended [B, B+S-1]  RWX.
 *  - PROBE = B + S lies just above the *intended* region but inside the
 *    2x-too-large region the core actually matches.
 *
 *  Drop to S-mode (PMP is default-deny there) and do a single load from PROBE:
 *      * Correct core: PROBE is not covered by any PMP entry -> Load access
 *        fault (mcause 5) at the probe `ld`; the trap handler recognises it
 *        and reports PASS.
 *      * Buggy core:  the oversized NAPOT entry matches -> the load succeeds,
 *        so we fall through to the explicit FAIL.
 */
#include "test.h"

  .globl test_main
  .globl trap_handler

  /* ---- addresses (DRAM base is 0x80000000) ------------------------------ */
  .set  BOUND,    0x80040000   /* entry 0 TOR upper bound (excl.)            */
  .set  B,        0x80050000   /* NAPOT region base                          */
  .set  S,        4096         /* intended NAPOT size                        */
  .set  PMPADDR0, 0x20010000   /* BOUND >> 2                                 */
  .set  PMPADDR1, 0x200143FF   /* (B >> 2) | (S/4 - 1)                       */
  .set  PROBE,    0x80051000   /* B + S, just past the intended region       */
  .set  PMPCFG,   0x1F0F       /* byte1 = 0x1F (NAPOT RWX), byte0 = 0x0F (TOR RWX) */

test_main:
  /* PMP is purely combinatorial: set the addresses before the config bytes. */
  li   t0, PMPADDR0
  csrw pmpaddr0, t0
  li   t0, PMPADDR1
  csrw pmpaddr1, t0
  li   t0, PMPCFG
  csrw pmpcfg0,  t0

  /* Probe address for the S-mode load (kept in t2 across the mret). */
  li   t2, PROBE

  /* Enter S-mode at the S-mode test.  MPP=1 -> supervisor. */
  ENTER_MODE(1, s_mode_test)

  /* Unreachable on the intended paths. */
  FAIL(99)

  .align 3
s_mode_test:
  /* Record the probe instruction's PC so the trap handler can confirm the
   * fault happened exactly there.  probe_pc lives in .data (inside BOUND).  */
  la   t5, probe_ld       /* t5 = address of the probe load                 */
  la   t6, probe_pc       /* t6 = address of the probe_pc global            */
  sd   t5, 0(t6)          /* probe_pc = address of probe_ld                 */

  .align 3
probe_ld:
  ld   t3, 0(t2)          /* load from PROBE = B + S                        */
  /* Reaching this point means the load was *allowed*: PMP matched an entry
   * that, by the specification, should not cover PROBE.  That is the bug.  */
  FAIL(1)

  /* ------------------------------------------------------------------------ */
  .align 2
trap_handler:
  /* Expect exactly the S-mode load fault raised by `probe_ld`: a Load access
   * fault (mcause 5; the bare S-mode PMP violation) -- accept a Load page fault
   * (13) defensively too.  Any other trap, or a different faulting PC, means
   * the test misbehaved -> FAIL.
   */
  csrr t4, mcause
  li   t5, 5                 /* 5  = Load access fault */
  beq  t4, t5, check_pc
  li   t5, 13                /* 13 = Load page fault   */
  beq  t4, t5, check_pc
  j    not_expected

check_pc:
  csrr t4, mepc
  la   t5, probe_pc
  ld   t5, 0(t5)             /* t5 = recorded PC of the probe load           */
  bne  t4, t5, not_expected

  /* The PMP correctly denied the out-of-region load: this is a good core. */
  PASS

not_expected:
  FAIL(127)

  /* ---- data ------------------------------------------------------------- */
  .section .data
probe_pc:
  .dword 0
