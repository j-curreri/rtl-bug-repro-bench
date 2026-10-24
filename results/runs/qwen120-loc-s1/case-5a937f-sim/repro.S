#include "test.h"

/* Reproducer for a privileged-ISA deviation in core/csr_regfile.sv.
 *
 * The `medeleg` write mask omits the bit for ENV_CALL_SMODE (cause 9,
 * "ECALL from S-mode").  Per the RISC-V privileged specification,
 * medeleg[9] is a writable bit: when set, an ECALL executed in S-mode is
 * taken in S-mode (at stvec) instead of in M-mode (at mtvec).  This core
 * silently forces medeleg[9] to 0, so an S-mode ECALL can never be handled
 * in S-mode and always traps to M-mode.
 *
 *   Correct core: medeleg[9] sticks; the S-mode ECALL routes to stvec and
 *                 scause==9        ->  PASS
 *   Buggy core:   medeleg[9] is not settable; the ECALL routes to mtvec   ->
 *                 FAIL
 */
  .globl test_main
  .align 2
test_main:
  PMP_ALLOW_ALL                     # grant S/U mode RWX over all of memory
  la   t0, s_trap
  csrw stvec, t0
  la   t0, m_trap
  csrw mtvec, t0
  li   t0, (1 << 9)                 # delegate ECALL from S-mode (cause 9)
  csrs medeleg, t0
  ENTER_MODE(1, s_body)             # mret into S-mode

s_body:
  ecall                             # ECALL from S-mode
  FAIL(50)                         # must not fall through

s_trap:                            # reached only when medeleg[9] works
  csrr t0, scause
  li   t1, 9
  bne  t0, t1, fail51
  PASS
fail51:
  FAIL(51)

m_trap:                            # reached iff the ECALL was NOT delegated
  FAIL(53)
