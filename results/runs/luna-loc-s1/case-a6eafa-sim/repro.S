#include "hyp.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* G-stage PTE.U is reserved and must be zero. */
  GIGA_LEAF(g_root, 1, 0x80000000, (PTE_V | PTE_R | PTE_W | PTE_X | PTE_U | PTE_A | PTE_D))
  csrw vsatp, zero
  HGATP_ON

  /* MPRV makes this M-mode load use S privilege in virtual mode. */
  li t0, (3 << 11)
  csrc mstatus, t0
  li t0, ((1 << 11) | (1 << 17) | MSTATUS_MPV)
  csrs mstatus, t0

  /* The address is translated as a GPA by the MPRV load. */
  li t0, 0x40000000
bad_load:
  ld t1, 0(t0)
  /* A conforming G-stage walker page-faults before completing the load. */
  li t0, (1 << 17)
  csrc mstatus, t0
  FAIL(3)

  .globl trap_handler
trap_handler:
  /* Disable the MPRV override before the handler writes to tohost. */
  li t0, (1 << 17)
  csrc mstatus, t0
  csrr t0, mepc
  la t1, bad_load
  bne t0, t1, unexpected_trap
  csrr t0, mcause
  li t1, 21                 /* load guest-page fault */
  bne t0, t1, unexpected_trap
  PASS
unexpected_trap:
  FAIL(2)

  HYP_TABLES
