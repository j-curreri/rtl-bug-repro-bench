#include "test.h"
  .text
  .globl test_main
  .globl trap_handler
test_main:
  la t1, target
  srli t1, t1, 2
  csrw pmpaddr0, t1        # NA4 region over target, no permissions
  li t0, -1
  csrw pmpaddr1, t0
  li t0, 0x1f10            # entry0: NA4, no perms; entry1: NAPOT RWX
  csrw pmpcfg0, t0
  ENTER_MODE(1, smode)
  .align 3
smode:
  la t1, target
  ld t2, 0(t1)             # must fault (load access fault)
  FAIL(1)
trap_handler:
  csrr t0, mcause
  li t1, 5
  bne t0, t1, bad
  PASS
bad:
  FAIL(2)
  .data
  .align 3
target:
  .dword 0x1234
