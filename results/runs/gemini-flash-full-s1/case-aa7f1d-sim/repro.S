#include "hyp.h"

  .globl test_main
test_main:
  PMP_ALLOW_ALL

  // Write distinct values to vsscratch and sscratch
  li t0, 0x1111
  csrw vsscratch, t0
  li t0, 0x2222
  csrw sscratch, t0

  // Set MPP = M-mode (3) and MPV = 1 in mstatus
  li t0, MSTATUS_MPV
  csrs mstatus, t0
  ENTER_MODE(3, 1f)

1:
  // On a correct core:
  // Returning to M-mode ignores MPV, leaving priv=M and V=0.
  // 1) Accessing sscratch reads sscratch (0x2222), not vsscratch (0x1111).
  // 2) hfence.vvma is legal in M-mode (V=0) and does not trap.
  //
  // On the buggy core:
  // priv=M but V=1 (inconsistent virtualization state).
  // Reading sscratch erroneously accesses vsscratch (0x1111).
  // Also, hfence.vvma erroneously causes a virtual instruction exception.

  csrr t2, sscratch
  li t3, 0x2222
  bne t2, t3, 2f

  hfence.vvma zero, zero

  PASS

2:
  FAIL(1)
