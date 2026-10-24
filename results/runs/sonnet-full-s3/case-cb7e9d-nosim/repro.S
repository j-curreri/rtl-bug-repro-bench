#include "harness/test.h"
.section .text
.globl test_main
.globl trap_handler
test_main:
  csrw tselect, x0
  li t0, 0x80002000 | 0x7ff     # NAPOT 4KiB range at 0x80002000
  csrw tdata2, t0
  li t0, (6 << 60) | (1 << 7) | (1 << 6) | 1   # mcontrol6, match=NAPOT, M, load, action=0
  csrw tdata1, t0
  li t1, 0x80002000
  lw t2, 0(t1)
  FAIL(1)
trap_handler:
  csrr t0, mcause
  li t1, 3
  bne t0, t1, 1f
  PASS
1:
  FAIL(2)
