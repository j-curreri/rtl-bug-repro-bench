#include "hyp.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Identity-map the DRAM 1 GiB region for G-stage accesses. */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)

  /* The VS code itself lives in DRAM, in root slot 2. */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)

  /*
   * A VS load from VA 0 uses root slot 0.  This is a valid non-leaf PTE,
   * but its next-level table is at GPA 2^41, outside the Sv39x4 GPA space.
   */
  RAW_PTE(vs_root, 0, ((1 << 29) << 10) | PTE_V)

  HGATP_ON
  la t0, vs_root
  VSATP_ON(t0)

  ENTER_VS(vs_code)

  .align 2
vs_code:
  ld t0, 0(zero)
  /* Reaching here means the malformed translation did not fault. */
  ebreak

  .section .text
  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 21                  /* Load guest-page fault. */
  beq t0, t1, expected_fault
  FAIL(1)
expected_fault:
  PASS

  HYP_TABLES
