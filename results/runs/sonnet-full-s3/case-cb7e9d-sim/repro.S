#include "test.h"
.option norvc
.text
.globl test_main
test_main:
  la t0, trap_handler
  csrw mtvec, t0
  li s1, 0
  li t0, 0
  csrw tselect, t0
  # mcontrol6: type=6, m=1, load=1, match=1 (NAPOT), action=0
  li t0, 6
  slli t0, t0, 60
  li t1, (1<<6) | (1<<0) | (1<<7)
  or t0, t0, t1
  csrw tdata1, t0
  # NAPOT range of 16 bytes at 0x80004000
  li t0, 0x80004007
  csrw tdata2, t0
  li t2, 0x80004008
  lw t3, 0(t2)
  beqz s1, nofire
  PASS
nofire:
  FAIL(1)

.align 2
.globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 3
  bne t0, t1, bad
  li s1, 1
  csrw tselect, x0
  csrw tdata1, x0
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret
bad:
  FAIL(2)
