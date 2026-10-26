#include "hyp.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Make matching 1 GiB VS-stage and G-stage mappings for the DRAM image.
     G-stage U is reserved and must be zero. The buggy PTW accepts it. */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  GIGA_LEAF(g_root,  2, 0x80000000, (G_RWX | PTE_U))

  HGATP_ON
  la t0, vs_root
  VSATP_ON(t0)

  /* The correct core raises instruction guest-page-fault (mcause=20)
     while translating this first VS instruction fetch. */
  ENTER_VS(guest_entry)

  .align 2
guest_entry:
  /* Reaching this code means the invalid G-stage PTE was accepted. */
  FAIL(1)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 20
  beq t0, t1, expected_guest_page_fault
  FAIL(2)
expected_guest_page_fault:
  PASS

HYP_TABLES
