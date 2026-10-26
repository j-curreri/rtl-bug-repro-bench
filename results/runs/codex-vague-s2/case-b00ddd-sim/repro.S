#include "hyp.h"

  .section .text
  .balign 4
  .globl test_main
test_main:
  /* Route the software interrupt directly to M-mode.  Keep MIE clear
   * while preparing it; lower privilege modes enable M interrupts
   * independently of mstatus.MIE. */
  csrw mie, zero
  csrw mideleg, zero
  csrw medeleg, zero
  li t0, 8
  csrc mstatus, t0
  PMP_ALLOW_ALL

  /* Both translation stages are Bare, so guest code and data use
   * their linked physical addresses. */
  csrw satp, zero
  csrw vsatp, zero
  csrw hgatp, zero
  la s0, datum

  li t0, 8
  csrw mie, t0
  li t0, 0x02000000
  li t1, 1
  sw t1, 0(t0)
  fence iorw, iorw
  ENTER_VS(guest)

  .balign 4
guest:
  /* The pending interrupt is recognized while decoding this load.
   * Its transformed instruction must NOT be reported for an interrupt. */
  ld t2, 0(s0)
  j guest

  .balign 4
  .globl trap_handler
trap_handler:
  /* Snapshot trap information before any CSR writes. */
  csrr s1, mcause
  csrr s2, mstatus
  csrr s3, mtinst
  csrr s4, mtval2
  csrr s5, mtval

  /* Deassert MSIP and disable interrupts before checking the result. */
  csrw mie, zero
  li t0, 0x02000000
  sw zero, 0(t0)
  fence iorw, iorw

  li t0, 0x8000000000000003
  bne s1, t0, bad_cause
  li t0, MSTATUS_MPV
  and t1, s2, t0
  beqz t1, bad_origin
  li t0, (3 << 11)
  and t1, s2, t0
  li t0, (1 << 11)
  bne t1, t0, bad_origin

  /* An interrupt supplies no faulting instruction or guest address. */
  bnez s3, bad_mtinst
  bnez s4, bad_mtval2
  li t0, MSTATUS_GVA
  and t1, s2, t0
  bnez t1, bad_gva
  bnez s5, bad_mtval
  PASS

bad_cause:
  FAIL(1)
bad_origin:
  FAIL(2)
bad_mtinst:
  FAIL(3)
bad_mtval2:
  FAIL(4)
bad_gva:
  FAIL(5)
bad_mtval:
  FAIL(6)

  .section .data
  .balign 8
datum:
  .dword 0x123456789abcdef0
