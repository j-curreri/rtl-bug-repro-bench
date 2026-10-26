#include "hyp.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* The guest code and its VS-stage root are in the mapped DRAM region. */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)

  /* VA 0x40000000 selects VS root entry 1.  This is a valid non-leaf PTE,
   * but its next-level table would be at GPA 2^41, outside Sv39x4's range. */
  RAW_PTE(vs_root, 1, ((1 << 39) | PTE_V))

  HGATP_ON
  la t0, vs_root
  VSATP_ON(t0)

  ENTER_VS(guest_test)

  .align 2
guest_test:
  li t0, 0x40000000
  ld t1, 0(t0)
  /* Reaching here means the malformed walk did not fault as required. */
  li a0, 1
  j _halt

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 21                 /* LOAD_GUEST_PAGE_FAULT */
  beq t0, t1, trap_expected
  FAIL(2)
trap_expected:
  PASS

HYP_TABLES
