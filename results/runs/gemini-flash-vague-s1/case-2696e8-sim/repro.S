#include "test.h"
#include "hyp.h"

  .globl test_main
  .globl trap_handler

test_main:
  PMP_ALLOW_ALL

  /* Ensure MXR is disabled so execute-only pages cannot be read by plain loads */
  li t0, (1 << 19)
  csrc mstatus, t0

  /* Set up G-stage root table */
  /* idx 2: 0x80000000 -> 0x80000000 (RWX) */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)

  /* idx 3: 0xc0000000 -> 0x80000000 (Execute-only: X, U, A, D, V; no R, no W) */
  GIGA_LEAF(g_root, 3, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A | PTE_D))

  /* Enable G-stage translation */
  HGATP_ON

  /* Enter HS-mode (mpp = 1) */
  ENTER_MODE(1, hs_test)

hs_test:
  li t2, 0xc0000000

  /* 1. Hypervisor execute-only load: succeeds on spec-compliant and buggy core,
   * populating the DTLB with an execute-only G-stage entry. */
  hlvx.wu a1, (t2)

  /* 2. Hypervisor plain load: on a spec-compliant core, this must fault with
   * LOAD_GUEST_PAGE_FAULT (mcause=21) because the G-stage page is execute-only.
   * On this buggy core, the DTLB hit path fails to re-check G-stage read permissions,
   * so it incorrectly succeeds and does not trap. */
load_hlv:
  hlv.w a2, (t2)

  /* Buggy core reaches here: FAIL */
  FAIL(1)

  .align 2
trap_handler:
  csrr t6, mcause
  li t0, 21 /* LOAD_GUEST_PAGE_FAULT */
  bne t6, t0, unexpected_trap

  /* Verify the fault occurred on the hlv.w instruction */
  la t1, load_hlv
  csrr t2, mepc
  bne t1, t2, unexpected_pc

  /* Correct core trapped as expected by the specification: PASS */
  PASS

unexpected_trap:
  FAIL(2)

unexpected_pc:
  FAIL(3)

HYP_TABLES
