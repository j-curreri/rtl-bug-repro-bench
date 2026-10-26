#include "hyp.h"

.globl trap_handler
trap_handler:
  csrr t6, mcause
  li t5, 13             /* Load page fault */
  bne t6, t5, trap_fail
  li t5, 1
  bne s0, t5, trap_fail
  PASS
trap_fail:
  FAIL(1)

.globl test_main
test_main:
  PMP_ALLOW_ALL

  /* DRAM at 0x80000000 */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 3, 0x80000000, G_RWX)
  HGATP_ON

  /* Code at 0x80000000: RWX in VS-stage */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  /* Target at 0xC0000000: Execute-only in VS-stage (X=1, R=0, W=0) */
  GIGA_LEAF(vs_root, 3, 0x80000000, (PTE_V | PTE_X | PTE_A | PTE_D))

  la a0, vs_root
  VSATP_ON(a0)

  /* Set hstatus.SPVP = 1 (Supervisor privilege for HLV/HLVX) */
  li t0, HSTATUS_SPVP
  csrs hstatus, t0

  /* Enter HS-mode (MPP = 1, MPV = 0) */
  ENTER_MODE(1, hs_entry)

hs_entry:
  li t2, 0xC0000000
  li s0, 0
  /* 1. HLVX succeeds on execute-only memory and populates the DTLB */
  hlvx.wu t3, (t2)
  li s0, 1
  /* 2. Plain HLV on the same page must raise Load Page Fault (cause 13) */
  hlv.w t4, (t2)

  /* If we reach here, no fault was raised (buggy core) */
  FAIL(2)

HYP_TABLES
