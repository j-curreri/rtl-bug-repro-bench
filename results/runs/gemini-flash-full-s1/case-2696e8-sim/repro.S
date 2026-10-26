#include "test.h"
#include "hyp.h"

  .globl test_main
test_main:
  PMP_ALLOW_ALL

  // Ensure MXR is 0 (make-executable-readable is disabled)
  li t0, (1 << 19)
  csrc mstatus, t0

  // Ensure VS-stage translation is disabled (Bare mode)
  csrw vsatp, zero

  // Set SPVP = 1 in hstatus
  li t0, HSTATUS_SPVP
  csrw hstatus, t0

  // Set up G-stage 1 GiB page table leaf at index 3 (GPA 0xC0000000..0xFFFFFFFF)
  // Maps to PA 0x80000000 with execute-only permission (X=1, R=0, W=0).
  // PTE flags: PTE_V | PTE_X | PTE_U | PTE_A | PTE_D
  GIGA_LEAF(g_root, 3, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A | PTE_D))

  // Enable G-stage translation (hgatp) and flush TLB
  HGATP_ON

  // Switch to HS-mode (Supervisor mode with H extension)
  ENTER_MODE(1, hs_start)

hs_start:
  li t2, 0xC0000000

  // Phase 1: HLVX reads from execute-only guest page.
  // According to RISC-V spec, HLVX may treat execute permission as read permission.
  // This must succeed without raising an exception.
  li s0, 1
  hlvx.wu a1, 0(t2)

  // Phase 2: Plain HLV load from the same execute-only page.
  // According to RISC-V spec, plain HLV requires read permission (R=1 or MXR=1).
  // Because G-stage maps this page execute-only (R=0) and MXR=0, HLV must raise
  // a LOAD_GUEST_PAGE_FAULT (cause 21).
  // On the buggy core, the DTLB cached the translation from HLVX and fails to
  // recheck read permissions on DTLB hit, so HLV incorrectly succeeds.
  li s0, 2
  hlv.w a2, 0(t2)

  // On the buggy core, HLV succeeds and does not trap, so execution reaches here:
  FAIL(1)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t6, mcause
  li t5, 2
  bne s0, t5, unexpected_trap
  li t5, 21 // LOAD_GUEST_PAGE_FAULT
  bne t6, t5, wrong_cause
  // Trap occurred during Phase 2 (HLV) with LOAD_GUEST_PAGE_FAULT as required by spec!
  PASS

unexpected_trap:
  FAIL(10)

wrong_cause:
  FAIL(11)

HYP_TABLES
