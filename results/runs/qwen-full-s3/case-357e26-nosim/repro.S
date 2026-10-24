/* Repro for the PMP TOR boundary bug.
 *
 * This core is specified to implement a PMP granularity of 8 bytes (G=1), so the
 * lowest bit of a pmpaddr value is don't-care and must be ignored when forming the
 * physical-address boundary of a TOR region. The CSR readback even forces that bit
 * to 0 for TOR entries (see csr_regfile.sv, "we only support granularity 8 bytes").
 *
 * However, the actual address match in pmp_entry.sv computes the boundary as
 * (pmpaddr << 2), which *includes* bit[0]. So when software writes a pmpaddr whose
 * lowest bit is set, a TOR entry protects a range 4 bytes larger than the spec says
 * it should: an access just at the (spec) boundary is matched against the wrong,
 * lower PMP entry.
 *
 * Setup (M-mode):
 *   entry 0: pmpcfg0 = 0x1f (TOR, RWX), pmpaddr0 = 0x20004001 (odd, bit[0]=1)
 *   entry 1: pmpcfg1 = 0x04 (TOR, no access), pmpaddr1 = 0x20004010
 *
 *   Spec-correct (G=1) entry-0 upper bound: (0x20004001 & ~1) << 2 = 0x80010000
 *   Buggy (bit[0] used) entry-0 upper bound:  0x20004001 << 2       = 0x80010004
 *
 *   T = 0x80010000:
 *     correct core -> T falls in entry 1 (deny) -> U-mode load access fault (cause 5)
 *     buggy core   -> T falls in entry 0 (allow) -> U-mode load succeeds
 *
 * We enter U-mode and perform a load at T. A spec-correct core denies the load and
 * traps (PASS); the buggy core lets the load through, after which we ecall to report
 * the misbehaviour (FAIL).
 */
#include "test.h"

  .section .text, "ax", @progbits
  .globl test_main
test_main:
  /* entry 0: TOR, RWX, not locked */
  li t0, 0x1f
  csrw pmpcfg0, t0
  li t0, 0x20004001
  csrw pmpaddr0, t0
  /* entry 1: TOR, no access */
  li t0, 0x04
  csrw pmpcfg1, t0
  li t0, 0x20004010
  csrw pmpaddr1, t0

  /* back the test address with a sentinel value (M-mode is not PMP-restricted) */
  li t0, 0x80010000
  li t1, 0x55555555
  sw t1, 0(t0)

  /* enter U-mode at u_entry */
  ENTER_MODE(0, u_entry)
  FAIL(3)               /* not reached: mret transfers control */

  .align 2
u_entry:
  li t0, 0x80010000
u_load:
  lw a0, 0(t0)          /* PMP load access fault on a spec-correct core */
u_ecall:
  ecall                 /* only reached on the buggy core (the load succeeded) */

  .align 2
  .globl trap_handler
trap_handler:
  /* The only two traps we expect are:
   *   - the U-mode load at u_load, if PMP (spec-correctly) denies it, or
   *   - the ecall at u_ecall, if the load was (incorrectly) allowed.
   * Distinguish them by mepc, independent of the exact cause code. */
  csrr t1, mepc
  la t2, u_load
  beq t1, t2, pass_fault
  la t2, u_ecall
  beq t1, t2, fail_allowed
  FAIL(2)               /* any other trap is unexpected */
pass_fault:
  /* our boundary load was denied -> PMP protects the expected range */
  PASS
fail_allowed:
  /* the boundary load succeeded -> PMP let through an address it must protect */
  FAIL(1)
