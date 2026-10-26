#include "hyp.h"

  .section .text
  .balign 4
  .globl test_main
test_main:
  /* Route the guest's illegal instruction directly to M-mode. */
  csrw mie, zero
  csrw medeleg, zero
  csrw mideleg, zero
  PMP_ALLOW_ALL

  /* Bare translation at both stages keeps guest addresses identical to PA. */
  csrw satp, zero
  csrw vsatp, zero
  csrw hgatp, zero
  sfence.vma
  hfence.gvma
  hfence.vvma

  /* Start with GVA clear; the trap must also report it clear. */
  li t0, MSTATUS_GVA
  csrc mstatus, t0
  ENTER_VS(illegal_site)

  .balign 4
illegal_site:
  /* An all-zero 16-bit encoding is always an illegal instruction.
   * With CV-X-IF enabled, the rejected instruction takes its exception path. */
  .2byte 0x0000
  .2byte 0x0000
  FAIL(1)

  .balign 4
  .globl trap_handler
trap_handler:
  /* Reject any setup fault or any trap other than the intended instruction. */
  csrr t0, mcause
  li t1, 2
  bne t0, t1, unexpected_trap
  csrr t0, mepc
  la t1, illegal_site
  bne t0, t1, unexpected_trap

  /* Confirm that the trapped instruction executed in VS-mode (MPV=1, MPP=S). */
  csrr t2, mstatus
  li t1, MSTATUS_MPV
  and t0, t2, t1
  beqz t0, unexpected_trap
  li t1, (3 << 11)
  and t0, t2, t1
  li t1, (1 << 11)
  bne t0, t1, unexpected_trap

  /* mtval for illegal instructions is zero or instruction bits, never a GVA. */
  li t1, MSTATUS_GVA
  and t0, t2, t1
  bnez t0, bad_gva
  PASS

bad_gva:
  FAIL(2)
unexpected_trap:
  FAIL(3)
