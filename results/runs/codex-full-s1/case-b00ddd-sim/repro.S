#include "hyp.h"

  .section .text
  .balign 4
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Route the guest's illegal-instruction exception directly to M-mode. */
  csrw medeleg, zero
  csrw hedeleg, zero
  csrw mideleg, zero
  csrw mie, zero

  /* Bare translation at both stages gives VS identity access to DRAM. */
  csrw satp, zero
  csrw vsatp, zero
  csrw hgatp, zero
  sfence.vma
  hfence.gvma
  hfence.vvma

  li t0, MSTATUS_GVA
  csrc mstatus, t0
  ENTER_VS(guest_illegal)

  .balign 4
guest_illegal:
  /* SLLI x0,x0,0 with reserved funct6=000001. The base decoder
   * offloads it to CV-X-IF, which must reject this encoding. */
  .word 0x04001013
  FAIL(1)

  .balign 4
  .globl trap_handler
trap_handler:
  csrr t3, mstatus
  csrr t0, mcause
  li t1, 2
  bne t0, t1, unexpected_trap
  csrr t0, mepc
  la t1, guest_illegal
  bne t0, t1, unexpected_trap

  /* Confirm that the exception really originated in VS-mode. */
  li t0, MSTATUS_MPV
  and t1, t3, t0
  beqz t1, unexpected_trap
  li t0, (3 << 11)
  and t1, t3, t0
  li t0, (1 << 11)
  bne t1, t0, unexpected_trap

  /* Illegal-instruction mtval is instruction bits (or zero), never a
   * guest virtual address. Consequently mstatus.GVA must be zero. */
  li t0, MSTATUS_GVA
  and t1, t3, t0
  bnez t1, bad_gva
  PASS

bad_gva:
  FAIL(2)
unexpected_trap:
  FAIL(3)
