#include "harness/test.h"
.option norvc
.text
.global test_main
test_main:
  la t0, trap_handler
  csrw mtvec, t0
  li s1, 0
  csrw tselect, x0
  la t1, buf
  ori t2, t1, 3            # NAPOT, 8-byte range at buf
  csrw tdata2, t2
  li t0, 6
  slli t0, t0, 60
  li t3, (1<<0)|(1<<6)|(1<<7)
  or t0, t0, t3
  csrw tdata1, t0
  ld t4, 0(t1)             # should raise breakpoint
  nop
  nop
  li t0, 1
  bne s1, t0, 1f
  PASS
1: FAIL(1)

.align 2
.global trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 3
  bne t0, t1, 2f
  addi s1, s1, 1
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret
2: FAIL(2)

.data
.align 4
buf: .dword 0x1234, 0
