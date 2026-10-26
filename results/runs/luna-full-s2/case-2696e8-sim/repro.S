#include "hyp.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  /* Build guest translations while still in M-mode.  GPA 0x40000000 is
   * execute-only and maps to DRAM; GPA 0x80000000 contains our page tables
   * and is fully accessible for the VS-stage page-table walks. */
  PMP_ALLOW_ALL

  GIGA_LEAF(g_root, 1, 0x80000000,
            (PTE_V | PTE_X | PTE_U | PTE_A | PTE_D))
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(vs_root, 1, 0x40000000, VS_RWX)

  HGATP_ON
  la t0, vs_root
  VSATP_ON(t0)

  /* HLV/HLVX perform their guest access as the SPVP privilege. */
  li t0, HSTATUS_SPVP
  csrs hstatus, t0
  la t0, trap_stage
  sw zero, 0(t0)

  ENTER_MODE(1, hs_test)

  .align 2
hs_test:
  /* HLVX may use execute permission as read permission. */
  li a1, 0x40000000
  hlvx.wu a0, (a1)

  /* A plain HLV load from that exact address must fault at G-stage. */
  li t0, 2
  la t1, trap_stage
  sw t0, 0(t1)
  hlv.wu a0, (a1)

  /* Reaching here means the execute-only mapping incorrectly allowed HLV. */
  FAIL(1)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 21                    /* load guest-page fault */
  bne t0, t1, unexpected_trap
  la t0, trap_stage
  lw t0, 0(t0)
  li t1, 2
  bne t0, t1, unexpected_trap
  PASS

unexpected_trap:
  FAIL(127)

  .section .bss
  .align 2
trap_stage:
  .word 0

  HYP_TABLES
