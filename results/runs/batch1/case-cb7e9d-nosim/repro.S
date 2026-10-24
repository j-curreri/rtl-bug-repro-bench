#include "harness/test.h"
  .text
  .globl test_main
test_main:
  la t0, trap_handler
  csrw mtvec, t0
  csrw tselect, x0
  csrw tdata1, x0
  # NAPOT range of 16 bytes at buf (16-aligned): tdata2 = buf | 0x7
  la t1, buf
  ori t1, t1, 7
  csrw tdata2, t1
  # mcontrol6: type=6, action=0 (breakpoint), match=1 (NAPOT), m=1, store=1
  li t0, 6
  slli t0, t0, 60
  li t1, (1 << 7) | (1 << 6) | (1 << 1)
  or t0, t0, t1
  csrw tdata1, t0
  csrr t2, tdata1
  srli t2, t2, 60
  li t3, 6
  bne t2, t3, nosupp
  la t1, buf
  addi t1, t1, 8        # inside the range, not the base
  li t0, 1
  sd t0, 0(t1)
  nop
  nop
  FAIL(1)               # trigger did not fire
nosupp:
  FAIL(2)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 3
  bne t0, t1, bad
  PASS
bad:
  FAIL(3)

  .data
  .align 4
buf: .dword 0, 0
