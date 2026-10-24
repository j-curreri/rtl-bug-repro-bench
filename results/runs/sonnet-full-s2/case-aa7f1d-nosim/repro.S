#include "test.h"
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  li t0, (3 << 11)
  csrs mstatus, t0          # MPP = M
  li t0, 1
  slli t0, t0, 39
  csrs mstatus, t0          # MPV = 1
  la t0, 1f
  csrw mepc, t0
  mret
1:
  la t1, data
  hlv.b t2, (t1)            # legal in M-mode with V=0; virtual-instruction trap if V=1
  li t3, 0x5a
  bne t2, t3, 2f
  PASS
2:
  FAIL(1)
  .data
data: .dword 0x5a
