#include "hyp.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* The guest's code, page tables, and stack live in the identity-mapped
     1 GiB region at GPA/HPA 0x80000000. */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  HGATP_ON

  /* Map the guest's code at its linked address, then map a second VA to a
     VS-stage PPN whose GPA is outside Sv39x4's 41-bit address space. */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  RAW_PTE(vs_root, 1, ((1 << 40) | VS_RWX))
  la t0, vs_root
  VSATP_ON(t0)
  ENTER_VS(guest)

  .align 2
guest:
  li t0, 0x40000000
  ld t1, 0(t0)
  /* The access must fault. Reaching here means the bad GPA was accepted. */
  FAIL(1)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 21                 /* load guest-page fault */
  beq t0, t1, expected_fault
  FAIL(2)
expected_fault:
  PASS

  HYP_TABLES
