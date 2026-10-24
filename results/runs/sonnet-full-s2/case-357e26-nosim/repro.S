#include "harness/test.h"
  .section .text
  .globl test_main
test_main:
  # entry0: TOR, top = 0x80004000 written with low bit set (G=1: bit must be ignored)
  li t0, 0x20001001
  csrw pmpaddr0, t0
  li t0, -1
  csrw pmpaddr1, t0
  # cfg0 = TOR|RWX (0x0f), cfg1 = TOR, no permissions (0x08)
  li t0, 0x0f | (0x08 << 8)
  csrw pmpcfg0, t0
  ENTER_MODE(0, umode)

  .align 2
umode:
  li t1, 0x80004000
  ld t2, 0(t1)          # must fault (entry 1, no permissions)
  ecall                 # reached only if the access wrongly succeeded

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 5
  bne t0, t1, bad
  PASS
bad:
  FAIL(1)
