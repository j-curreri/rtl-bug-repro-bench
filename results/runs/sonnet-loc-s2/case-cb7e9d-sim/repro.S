#include "harness/test.h"
.text
.globl test_main
test_main:
  PMP_ALLOW_ALL
  li t0, 1
  csrw tselect, t0
  # NAPOT: tdata2 = 0x800030ff -> 0x80003000..0x800030ff region (low bits ignored)
  li t1, 0x80003010
  li t0, 0x800030ff
  csrw tdata2, t0
  # mcontrol6: type 6, m=1, match=1 (napot), store=1, action=0
  li t0, 6
  slli t0, t0, 60
  ori t0, t0, (1<<6) | (1<<7) | 2
  csrw tdata1, t0
  nop
  sd x0, 0(t1)
  nop
  FAIL(1)

.globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 3
  bne t0, t1, 1f
  PASS
1:
  FAIL(2)
