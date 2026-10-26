#include "test.h"
#include "hyp.h"

  .globl trap_handler
trap_handler:
  csrr t6, mcause
  li t5, 21                  /* LOAD_GUEST_PAGE_FAULT */
  bne t6, t5, 1f
  PASS                       /* Correct core trapped with LOAD_GUEST_PAGE_FAULT -> PASS */
1:
  FAIL(127)

  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Set up g_root: map gigapage 2 (0x80000000) as execute-only (X=1, R=0, W=0) */
  #define G_X (PTE_V | PTE_X | PTE_U | PTE_A | PTE_D)
  GIGA_LEAF(g_root, 2, 0x80000000, G_X)

  /* Ensure vsatp is Bare (0) */
  csrw vsatp, zero

  /* Turn on G-stage translation with HGATP_ON */
  HGATP_ON

  /* Target GPA in gigapage 2 */
  li s0, 0x80000000

  /* 1. Execute HLVX.WU to prime the DTLB with the execute-only G-stage mapping */
  hlvx.wu a0, (s0)

  /* 2. Execute plain HLV.W on the same address.
   * According to the RISC-V Hypervisor Specification, an ordinary load cannot
   * read from an execute-only page when MXR=0, so this MUST raise a
   * LOAD_GUEST_PAGE_FAULT (mcause = 21).
   *
   * On the buggy core, line 650 of cva6_mmu.sv fails to check !g_load_access_ok
   * on a DTLB hit, so HLV.W erroneously succeeds without trapping.
   * Execution reaches FAIL(1).
   *
   * On a correct core, HLV.W traps with LOAD_GUEST_PAGE_FAULT, and trap_handler
   * calls PASS.
   */
  hlv.w a1, (s0)

  /* Buggy core did not trap on plain load */
  FAIL(1)

  HYP_TABLES
