#include "test.h"
.option norvc
.text
.globl test_main
test_main:
  la t0, trap_handler
  csrw mtvec, t0
  li s1, 0
  li t0, 0x800021ff        # NAPOT: 1KiB range at 0x80002000
  slli t0, t0, 0
  csrw tselect, x0
  csrw tdata2, t0
  li t1, 6
  slli t1, t1, 60
  ori t1, t1, 0xc1         # match=1 (NAPOT), m=1, load=1
  csrw tdata1, t1
  li t2, 0x80002100
  lw t3, 0(t2)             # must trap (breakpoint)
  csrw tdata1, x0
  li t0, 1
  bne s1, t0, fail
  PASS
fail:
  FAIL(1)
.align 4
.globl trap_handler
trap_handler:
  csrr t5, mcause
  li t6, 3
  bne t5, t6, bad
  addi s1, s1, 1
  csrr t5, mepc
  addi t5, t5, 4
  csrw mepc, t5
  mret
bad:
  FAIL(2)
