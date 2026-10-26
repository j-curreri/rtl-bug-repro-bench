#include "test.h"
#include "hyp.h"

  .globl test_main
test_main:
  PMP_ALLOW_ALL

  // Set MPV = 1 in mstatus
  li t0, MSTATUS_MPV
  csrs mstatus, t0

  // Set MPP = 3 (M-mode) in mstatus
  li t0, (3 << 11)
  csrs mstatus, t0

  // Set mepc to 1f
  la t0, 1f
  csrw mepc, t0
  mret

1:
  // On buggy core:
  //   - V is set to 1 in M-mode, so hfence.vvma causes a Virtual Instruction trap (FAIL(127))
  //   - mstatus.MPV is cleared to 0 (FAIL(1))
  // On correct core (per RISC-V spec):
  //   - V remains 0, so hfence.vvma executes without trapping
  //   - mstatus.MPV is not modified, so it remains 1
  hfence.vvma

  csrr t0, mstatus
  li t1, MSTATUS_MPV
  and t0, t0, t1
  beqz t0, 2f

  PASS

2:
  FAIL(1)
