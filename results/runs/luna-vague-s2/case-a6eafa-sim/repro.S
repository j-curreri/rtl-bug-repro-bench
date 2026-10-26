#include "hyp.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Map the guest's 0x80000000 region to DRAM at the G stage. */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  HGATP_ON

  /* VS-stage translation produces a GPA with bit 41 set.  Sv39x4 only
   * supports 41-bit GPAs, so fetching from this mapping must guest-page-fault. */
  GIGA_LEAF(vs_root, 2, 0x20000000000, VS_RWX)
  la t0, vs_root
  VSATP_ON(t0)

  ENTER_VS(guest_entry)

guest_entry:
  /* Correct hardware traps on this first fetch, before this instruction. */
  FAIL(1)

  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 20                    /* instruction guest-page fault */
  beq t0, t1, 1f
  FAIL(2)
1:
  PASS

HYP_TABLES
