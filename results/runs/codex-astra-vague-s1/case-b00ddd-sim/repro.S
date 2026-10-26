#include "hyp.h"

  .section .text
  .option norvc
  .globl test_main
test_main:
  csrw mie, zero
  csrw medeleg, zero
  csrw mideleg, zero
  PMP_ALLOW_ALL
  csrw satp, zero
  csrw vsatp, zero
  csrw hgatp, zero
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  fence rw, rw
  HGATP_ON
  ENTER_VS(guest)

guest:
  li a1, 0x40001000
faulting_load:
  ld a2, 0(a1)
  FAIL(1)

  .balign 4
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 21
  bne t0, t1, bad_cause
  csrr t0, mepc
  la t1, faulting_load
  bne t0, t1, bad_epc
  csrr t0, mtval
  li t1, 0x40001000
  bne t0, t1, bad_tval
  csrr t0, mstatus
  li t1, MSTATUS_MPV | MSTATUS_GVA
  and t0, t0, t1
  bne t0, t1, bad_status
  csrr t0, mtval2
  beqz t0, check_inst
  li t1, 0x10000400
  bne t0, t1, bad_tval2
check_inst:
  csrr t0, mtinst
  beqz t0, passed
  li t1, 0x00003603
  bne t0, t1, bad_inst
passed:
  PASS
bad_cause:
  FAIL(2)
bad_epc:
  FAIL(3)
bad_tval:
  FAIL(4)
bad_status:
  FAIL(5)
bad_tval2:
  FAIL(6)
bad_inst:
  FAIL(7)

  HYP_TABLES
