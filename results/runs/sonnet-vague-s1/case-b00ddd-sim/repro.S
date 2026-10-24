#include "hyp.h"
.text
.globl test_main
.globl trap_handler
test_main:
  PMP_ALLOW_ALL
  csrw medeleg, zero
  csrw mideleg, zero
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  HGATP_ON
  li s3, 0
  ENTER_VS(vs_code)
.align 2
vs_code:
  la a2, c2
  li a1, 0x1000
  ld a6, 0(a1)       # load guest page fault
c2:
  la a2, c3
  .word 0xffffffff   # illegal instruction
c3:
  li s3, 100
  ecall
.align 2
trap_handler:
  li t1, 100
  beq s3, t1, done
  csrr t0, mcause
  li t1, 21
  beq t0, t1, ok
  li t1, 2
  beq t0, t1, ill
  FAIL(1)
ill:
  csrr t2, mstatus
  srli t3, t2, 38    # GVA must be 0 for illegal instruction
  andi t3, t3, 1
  beqz t3, ok
  FAIL(3)
ok:
  addi s3, s3, 1
  csrw mepc, a2
  li t0, MSTATUS_MPV
  csrs mstatus, t0
  li t0, (3<<11)
  csrc mstatus, t0
  li t0, (1<<11)
  csrs mstatus, t0
  mret
done:
  PASS
HYP_TABLES
