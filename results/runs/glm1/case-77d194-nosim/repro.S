# repro.S -- reproducer for the CVA6 hgatp bug.
#
# Bug: a write to hgatp with an unsupported MODE value is dropped entirely --
# none of the other fields change (csr_regfile.sv only assigns hgatp_d when the
# mode is ModeOff or the core's single supported VM mode).  The hypervisor spec
# says such a write is *not* ignored the way it is for satp: hgatp is a WARL
# register in the normal way, so VMID and PPN must still take the written
# values; only MODE may legally end up holding some other supported encoding.
#
# Strategy: in M-mode and again in HS-mode (V=0, TVM=0, where hgatp access is
# allowed), first zero hgatp with a supported write (MODE = Bare), then write an
# unsupported MODE together with distinctive VMID/PPN payloads and read hgatp
# back.
#   * spec-correct core: VMID/PPN hold the written values          -> PASS
#   * buggy core:        VMID/PPN still hold the baseline (zero)   -> FAIL
# Only the plain read/write fields VMID[57:44] and PPN[43:2] are compared, so
# the value a corrected core puts into MODE is irrelevant.  VMID/PPN payloads
# stay well inside the guaranteed field widths (7-bit VMID, low PPN bits).
# Payload bits [1:0] of PPN are zero, since they are hardwired to zero on write.

#include "test.h"

  .globl test_main
test_main:
  PMP_ALLOW_ALL

  # Defensive: TVM must be clear so HS-mode gets hgatp access (it is 0 at
  # reset; clear it explicitly anyway).
  li   t0, (1 << 20)
  csrc mstatus, t0

  # -----------------------------------------------------------------------
  # Leg A: hgatp written from M-mode.
  # -----------------------------------------------------------------------
  li   t0, 0
  csrw hgatp, t0                  # baseline: MODE = Bare, VMID = 0, PPN = 0

  li   t1, (9 << 60) | (0x55 << 44) | 0x40  # unsupported MODE = 9
  csrw hgatp, t1
  csrr t3, hgatp

  # Compare only VMID[57:44] and PPN[43:2]; MODE and PPN[1:0] are excluded.
  li   t2, (1 << 58) - 4
  and  t3, t3, t2
  and  t1, t1, t2
  bne  t3, t1, .Lfail_a           # fields did not take the written value

  # -----------------------------------------------------------------------
  # Leg B: same write, but from HS-mode (S privilege with V = 0).
  # -----------------------------------------------------------------------
  ENTER_MODE(1, .Lhs)

.Lhs:
  li   t0, 0
  csrw hgatp, t0                  # baseline: MODE = Bare, VMID = 0, PPN = 0

  li   t1, (10 << 60) | (0x2A << 44) | 0x24  # unsupported MODE = 10
  csrw hgatp, t1
  csrr t3, hgatp

  li   t2, (1 << 58) - 4
  and  t3, t3, t2
  and  t1, t1, t2
  bne  t3, t1, .Lfail_b           # fields did not take the written value

  PASS

.Lfail_a:
  FAIL(1)                         # M-mode write ignored entirely
.Lfail_b:
  FAIL(2)                         # HS-mode write ignored entirely