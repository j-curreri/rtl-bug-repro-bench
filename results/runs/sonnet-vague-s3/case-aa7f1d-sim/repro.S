#include "hyp.h"
.text
.globl test_main
test_main:
  PMP_ALLOW_ALL
  la t0, trap_handler
  csrw mtvec, t0
  li t0, MSTATUS_MPV
  csrs mstatus, t0
  li t0, (3 << 11)
  csrs mstatus, t0
  la t0, 1f
  csrw mepc, t0
  mret
1:
  # still in M-mode with V=0: an M-only CSR access must work, and mstatus.MPV must be 0
  csrr t1, mstatus
  li t0, MSTATUS_MPV
  and t1, t1, t0
  bnez t1, 2f
  # try hypervisor-extension instruction use: hlv.b is legal in M-mode only if V=0
  la t2, trap_handler
  la a1, data
  hlv.b t3, (a1)
  PASS
2: FAIL(1)
.align 2
trap_handler:
  csrr a2, mcause
  addi a2,a2,-22
  bnez a2, 3f
  FAIL(2)
3: FAIL(3)
.data
data: .dword 0
