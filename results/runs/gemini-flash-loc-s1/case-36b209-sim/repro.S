#include "hyp.h"

#define PTE_X_ONLY (PTE_V | PTE_X | PTE_A | PTE_D)
#define MSTATUS_MXR (1 << 19)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 13 // Load page fault
  bne t0, t1, fail_trap
  PASS

fail_trap:
  FAIL(2)

  .globl test_main
test_main:
  PMP_ALLOW_ALL

  // Set up 1:1 G-stage mapping for 0x80000000 (DRAM, 1 GiB) with RWX
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  HGATP_ON

  // Set up 1:1 VS-stage mapping for 0x80000000 (DRAM, 1 GiB) as EXECUTE-ONLY (X=1, R=0, W=0)
  la a0, vs_root
  GIGA_LEAF(vs_root, 2, 0x80000000, PTE_X_ONLY)
  VSATP_ON(a0)

  // Ensure vsstatus.MXR = 0
  csrw vsstatus, zero

  // Keep mstatus.MXR = 0
  li t0, MSTATUS_MXR
  csrc mstatus, t0

  ENTER_VS(vs_code)

vs_code:
  la a0, vs_code
  lb a1, 0(a0)
  FAIL(1)

HYP_TABLES
