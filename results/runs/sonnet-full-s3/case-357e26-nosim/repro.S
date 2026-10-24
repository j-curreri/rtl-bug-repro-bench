#include "harness/test.h"
.text
.globl test_main
.globl trap_handler
test_main:
  la t0, trap_handler
  csrw mtvec, t0
  # entry0: TOR [0, 0x80100000) RWX, pmpaddr bit0 set (G=1: must be ignored)
  li t0, ((0x80100000 >> 2) | 1)
  csrw pmpaddr0, t0
  # entry1: TOR up to top, no permissions
  li t0, -1
  csrw pmpaddr1, t0
  li t0, (0x0f | (0x08 << 8))
  csrw pmpcfg0, t0
  ENTER_MODE(0, umode)
.align 2
umode:
  li t1, 0x80100000
  lb t2, 0(t1)          # outside entry0 -> must fault
  ecall                 # reached only on buggy core
.align 2
trap_handler:
  csrr t0, mcause
  li t1, 5
  bne t0, t1, bad
  PASS
bad:
  FAIL(1)
