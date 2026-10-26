#include "hyp.h"

  .section .text
  .option norvc
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  csrw medeleg, zero
  csrw mie, zero
  csrw satp, zero
  csrw vsatp, zero
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  HGATP_ON
  ENTER_VS(guest)

guest:
  li s0, 0x40001238
fault:
  ld a1, 0(s0)
  FAIL(1)

  .balign 4
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 21
  bne t0, t1, bad_cause
  csrr t0, mepc
  la t1, fault
  bne t0, t1, bad_pc
  csrr t0, mtval
  bne t0, s0, bad_tval
  csrr t0, mtval2
  srli t1, s0, 2
  bne t0, t1, bad_tval2
  csrr t0, mstatus
  li t1, MSTATUS_GVA
  and t0, t0, t1
  beqz t0, bad_gva
  csrr t0, mtinst
  bnez t0, bad_tinst
  PASS
bad_cause: FAIL(2)
bad_pc: FAIL(3)
bad_tval: FAIL(4)
bad_tval2: FAIL(5)
bad_gva: FAIL(6)
bad_tinst: FAIL(7)

HYP_TABLES
