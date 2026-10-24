#include "test.h"
.globl test_main
.globl trap_handler
.align 2
test_main:
  la t0, trap_handler
  csrw mtvec, t0
  li t0, 0x80100000
  srli t0, t0, 2
  ori t0, t0, 0x1ff
  csrw pmpaddr0, t0
  li t0, -1
  csrw pmpaddr1, t0
  li t0, 0x1f18
  csrw pmpcfg0, t0
  csrw satp, x0
  li t0, 0x20000
  csrs mstatus, t0          # MPRV=1
  ENTER_MODE(1, smode)
smode:
  ecall
after:
  li t1, 0x80100000
  ld t2, 0(t1)              # M-mode: must not fault if MPRV cleared
  PASS
.align 2
trap_handler:
  csrr t0, mcause
  li t1, 9
  bne t0, t1, bad
  la t0, after
  csrw mepc, t0
  li t0, (3<<11)
  csrs mstatus, t0          # return to M
  mret
bad:
  FAIL(1)
