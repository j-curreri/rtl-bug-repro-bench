#include "test.h"
  .text
  .globl test_main
  .globl trap_handler
test_main:
  PMP_ALLOW_ALL
  la t0, trap_handler
  csrw mtvec, t0
  li t0, (1 << 17)
  csrs mstatus, t0          # MPRV = 1
  ENTER_MODE(1, smode)
  .align 2
smode:
  csrr t1, sstatus          # MPRV not visible in sstatus; use ecall to M
  ecall
  .align 2
trap_handler:
  csrr t0, mstatus
  li t1, (1 << 17)
  and t0, t0, t1
  beqz t0, ok
  FAIL(1)
ok:
  PASS
