#include "harness/test.h"
.text
.globl test_main
test_main:
  la t0, target
  srli t0, t0, 2
  csrw pmpaddr0, t0
  li t0, -1
  csrw pmpaddr1, t0
  li t0, 0x1f10
  csrw pmpcfg0, t0
  ENTER_MODE(1, smode)
smode:
  la t1, target
  lw t2, 0(t1)
  FAIL(1)          # no fault: NA4 entry did not match (ecall not reached)

.globl trap_handler
.align 2
trap_handler:
  csrr t0, mcause
  li t1, 5
  bne t0, t1, bad
  PASS
bad:
  FAIL(2)

.data
.align 3
target: .dword 0x1234
