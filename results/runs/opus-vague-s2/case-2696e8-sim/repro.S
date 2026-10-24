/* HLV must enforce G-stage read permission even when the translation is
 * already cached in the DTLB by a preceding HLVX on an execute-only page. */
#include "hyp.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* G-stage: GPA 0x80000000 -> PA 0x80000000, execute-only (no R/W). */
  GIGA_LEAF(g_root, 2, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A | PTE_D))
  csrw satp, zero
  csrw vsatp, zero
  HGATP_ON
  li s0, 0
  ENTER_MODE(1, hs_code)

hs_code:
  la a2, data
  li s0, 1
  /* HLVX on an executable page is allowed; fills the DTLB. */
  hlvx.wu a0, (a2)
  li t0, 0x12345678
  bne a0, t0, 1f
  li s0, 2
  /* Plain HLV on the now-cached execute-only page must fault. */
  hlv.w a1, (a2)
  li s0, 3
  ecall
1:
  ecall

  .align 2
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  li t0, 2
  bne s0, t0, 2f
  li t0, 21           /* load guest-page fault */
  bne t6, t0, 3f
  PASS
2:
  li t0, 1
  beq s0, t0, 4f
  FAIL(3)   /* HLV completed without fault, or other */
4:
  FAIL(1)   /* HLVX trapped */
3:
  FAIL(4)

  .data
  .align 3
data: .word 0x12345678
HYP_TABLES
