#include "hyp.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Map GPA 0x80000000 through a G-stage leaf with reserved U=1. */
  RAW_PTE(g_root, 2, 0x200000df)
  /* The VS-stage maps GVA 0x80000000 to the same GPA. */
  RAW_PTE(vs_root, 2, 0x200000cf)

  HGATP_ON
  la t0, vs_root
  VSATP_ON(t0)

  /* On a conforming core this fetch faults before guest code executes. */
  ENTER_VS(guest_entry)

  .align 2
guest_entry:
  FAIL(2)

  .globl trap_handler
trap_handler:
  /* Instruction guest-page fault is cause 20. */
  csrr t0, mcause
  li t1, 20
  bne t0, t1, unexpected_trap
  PASS
unexpected_trap:
  FAIL(127)

  HYP_TABLES
