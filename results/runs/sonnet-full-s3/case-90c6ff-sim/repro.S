#include "harness/test.h"
#include "harness/hyp.h"
.text
.globl test_main
test_main:
  PMP_ALLOW_ALL
  GIGA_LEAF(g_root, 514, 0x80000000, G_RWX)
  HGATP_ON
  csrw vsatp, zero
  li t0, MSTATUS_MPV
  csrs mstatus, t0
  li t0, (3 << 11)
  csrc mstatus, t0
  li t0, (1 << 11)
  csrs mstatus, t0
  la t0, guest
  li t1, 1
  slli t1, t1, 39
  add t0, t0, t1
  csrw mepc, t0
  mret
.align 2
guest:
  li a1, 0x1234
  ecall
.align 2
.globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 10          # ecall from VS-mode
  bne t0, t1, bad
  PASS
bad:
  FAIL(1)
HYP_TABLES
