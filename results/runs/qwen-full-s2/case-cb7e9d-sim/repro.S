/* repro.S — reproducer for the Sdtrig mcontrol6 NAPOT (match=1) address-match bug.
 *
 * The NAPOT match helpers (napot_match32/64 in triggers_pkg.sv) reject a trigger
 * whenever (tdata2 & (tdata2 + 1)) != 0.  A NAPOT trigger with tdata2 having k
 * trailing 1-bits is supposed to cover the naturally aligned power-of-two region
 * [tdata2 - 2^k + 1, tdata2]; for tdata2 = B + 3 (B 16-byte aligned) that is
 * [B, B + 3] and B + 3 & (B + 4) = 4m & (4m + 1) = 4m != 0 for any B in DRAM.
 * The buggy core therefore treats the encoding as "invalid" and the trigger
 * never fires, although a fetch at B is inside the configured range.  Exact
 * match (match = 0) is not affected.
 *
 * The program arms mcontrol6 execute-address breakpoint triggers:
 *   test 1: match = exact on pc_a      -> must fire on any spec-compliant core
 *          (also fires on the buggy core; sanity check of the trigger plumbing)
 *   test 2: match = NAPOT, tdata2 = pc_b + 3, region [pc_b, pc_b + 3]
 *          -> must fire on a spec-compliant core; the buggy core does not fire.
 *
 * On a correct core both triggers fire and the program ends with PASS.
 * On the buggy core test 2 does not fire, so it ends with FAIL(2).
 */

#include "test.h"

/* Trigger CSR numbers of this core (see csr_regfile.sv / riscv_pkg.sv) */
#define CSR_TSELECT  0x7A0
#define CSR_TDATA1   0x7A1
#define CSR_TDATA2   0x7A2

/* mcontrol6 tdata1: type 6 [63:60], action = breakpoint (0) [15:12],
 * match [10:7], M-mode [6], execute [2] */
#define TD1_EXACT    0x6000000000000044  /* match = 0 (exact)   */
#define TD1_NAPOT    0x6000000000000084  /* match = 1 (NAPOT)   */

#define CAUSE_BREAKPOINT 3

  .text
  .globl test_main

test_main:
  /* ---- test 1: execute trigger, exact match on pc_a ---- */
  li   t0, 0
  csrw CSR_TSELECT, t0
  li   t0, TD1_EXACT
  csrw CSR_TDATA1, t0
  la   t0, pc_a
  csrw CSR_TDATA2, t0
  jr   t0
  /* no trap: the exact-match trigger failed to fire (should not happen) */
fail1:
  FAIL(1)

.align 4
pc_a:
  .word 0x00000013   /* 4-byte nop */
  j fail1            /* executed only if the trigger did not fire */

after1:
  /* ---- test 2: execute trigger, NAPOT match, region [pc_b, pc_b + 3] ----
   * pc_b is 16-byte aligned, so tdata2 = pc_b + 3 encodes the 4-byte region
   * [pc_b, pc_b + 3] and (tdata2 & (tdata2 + 1)) = 4m & (4m + 1) != 0, which
   * the buggy core's validity check rejects. */
  li   t0, 0
  csrw CSR_TSELECT, t0
  li   t0, TD1_NAPOT
  csrw CSR_TDATA1, t0
  la   t0, pc_b
  addi t1, t0, 3
  csrw CSR_TDATA2, t1
  jr   t0
  /* no trap: the NAPOT trigger failed to fire (the reported bug) */
fail2:
  FAIL(2)

.align 4
pc_b:
  .word 0x00000013   /* 4-byte nop, fills the whole [pc_b, pc_b+3] region */
  j fail2            /* executed only if the trigger did not fire */

after2:
  PASS

/* Both tests run in M-mode; the armed trigger fires a breakpoint exception
 * at the target PC.  The handler disables the trigger (so it cannot fire
 * again) and redirects execution to the corresponding "after" label. */
  .global trap_handler
  .align 2
trap_handler:
  li   a5, CAUSE_BREAKPOINT
  csrr t6, mcause
  bne  t6, a5, trap_bad
  csrr t2, mepc
  la   a4, pc_a
  beq  t2, a4, h_test1
  la   a4, pc_b
  bgeu t2, a4, in_range
  j    trap_bad
in_range:
  addi a5, a4, 3
  bleu t2, a5, h_test2
  j    trap_bad
h_test1:
  li   t0, 0
  csrw CSR_TSELECT, t0
  csrw CSR_TDATA1, t0
  la   t0, after1
  csrw mepc, t0
  mret
h_test2:
  li   t0, 0
  csrw CSR_TSELECT, t0
  csrw CSR_TDATA1, t0
  la   t0, after2
  csrw mepc, t0
  mret
trap_bad:
  FAIL(127)
