#include "test.h"
.globl test_main
.globl trap_handler
# xRET to a less-privileged mode must clear MPRV (priv spec, mstatus MPRV).
test_main:
  PMP_ALLOW_ALL
  li s2, 0
  li t0, (1 << 17)
  csrs mstatus, t0      # MPRV=1 (MPP=M so harmless)
  ENTER_MODE(0, user)   # mret to U must clear MPRV
user:
  ecall
1: j 1b

.align 2
trap_handler:
  csrr t0, mcause
  li t1, 8
  bne t0, t1, bad0
  csrr t0, mstatus
  li t1, (1 << 17)
  and t0, t0, t1
  bnez t0, bad
  bnez s2, done
  # stage 2: sret from M-mode into U with MPRV=1
  li s2, 1
  csrs mstatus, t1       # MPRV=1
  li t0, (1 << 8)
  csrc mstatus, t0       # SPP=U
  la t0, user2
  csrw sepc, t0
  la t0, user2
  # return target of the trap handler after ecall is via sret
  sret
done:
  PASS
bad:
  FAIL(1)
bad0:
  FAIL(2)
user2:
  ecall
2: j 2b
