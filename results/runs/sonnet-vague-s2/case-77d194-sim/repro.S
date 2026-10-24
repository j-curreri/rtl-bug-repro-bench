#include "hyp.h"
.globl test_main
.globl trap_handler
trap_handler:
  csrr t5, mcause
  li t4, 10
  beq t5, t4, back
  csrr s3, mcause
  j .
back:
  li t5, (3<<11)
  csrs mstatus, t5
  la t5, cont
  csrw mepc, t5
  mret
test_main:
  PMP_ALLOW_ALL
  li t0, 0x1111
  csrw satp, t0
  li t0, 0x2222
  csrw vsatp, t0
  ENTER_VS(vs)
vs:
  csrr t0, satp
  li t1, 0x2222
  bne t0, t1, 1f
  li t0, 0x3333
  csrw satp, t0
  ecall
cont:
  csrr t0, satp
  li t1, 0x1111
  bne t0, t1, 2f
  csrr t0, vsatp
  li t1, 0x3333
  bne t0, t1, 3f
  # HS-mode satp write must not touch vsatp
  li t0, 0x4444
  csrw satp, t0
  csrr t0, vsatp
  li t1, 0x3333
  bne t0, t1, 4f
  PASS
1: FAIL(1)
2: FAIL(2)
3: FAIL(3)
4: FAIL(4)
