#include "test.h"
#include "hyp.h"

/* Bug: the DTLB hit path for hypervisor loads checks G-stage permissions without
 * the R-or-execute-as-read rule. After an HLVX load fills the TLB with an execute-only
 * G-stage leaf, a plain HLV to the same page hits the TLB and succeeds instead of raising
 * a load guest-page fault (cause 21). */

HYP_TABLES

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* G-stage: GPA 0x80000000 -> PA 0x80000000, 1 GiB leaf, execute-only (R=0, X=1, U=1). */
  GIGA_LEAF(g_root, 2, 0x80000000, PTE_V | PTE_X | PTE_U | PTE_A | PTE_D)
  HGATP_ON
  /* VS-stage stays in Bare mode (vsatp = 0), so the guest address is the GPA. */

  /* Step 1: HLVX must read the execute-only page (spec-correct on both cores). */
  li a0, 0x80000100
  la t0, trap_cause
  sd zero, 0(t0)
  hlvx.wu a1, (a0)
  la t0, trap_cause
  ld t1, 0(t0)
  bnez t1, 1f
  j 2f
1:
  FAIL(1)
2:

  /* Step 2: plain HLV to the same page must fault with a load guest-page fault. */
  li a0, 0x80000100
  hlv.w a2, (a0)

  la t0, trap_cause
  ld t1, 0(t0)
  li t2, 21
  bne t1, t2, 3f
  PASS
3:
  FAIL(2)

  /* Trap handler: record mcause, skip the faulting 4-byte instruction. */
  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  la t1, trap_cause
  sd t0, 0(t1)
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret

  .data
  .align 3
trap_cause: .dword 0
