/* Reproducer: an HLVX load from a guest page that the G-stage maps execute-only
 * fills the DTLB; a following plain HLV load from the same page must still raise
 * a load guest-page fault (mcause 21). The buggy core lets the HLV succeed. */
#include "hyp.h"

#define CAUSE_LOAD_GUEST_PAGE_FAULT 21
#define XO_GPA_BASE 0xC0000000      /* G-stage index 3: execute-only alias of DRAM */

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* G-stage: GPA 0x80000000 -> PA 0x80000000 RWX (idx 2),
   *          GPA 0xC0000000 -> PA 0x80000000 execute-only (idx 3). */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 3, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A | PTE_D))
  HGATP_ON
  csrw vsatp, zero               /* VS-stage bare: GVA == GPA */
  hfence.vvma

  /* Guest accesses performed at VS privilege. */
  li t0, HSTATUS_SPVP
  csrs hstatus, t0

  /* s0 = guest address of `magic` through the execute-only alias. */
  la s0, magic
  li t0, 0x80000000
  sub s0, s0, t0
  li t0, XO_GPA_BASE
  add s0, s0, t0

  li s1, 0                       /* number of load guest-page faults taken */
  li s2, 0                       /* last faulting mtval2 */

  ENTER_MODE(1, hs_code)

hs_code:
  /* 1) HLVX on an execute-only G-stage page must succeed. */
  hlvx.wu a1, (s0)
  li t1, 0
  bnez s1, fail_hlvx             /* trapped: unexpected */
  la t2, magic
  lwu t2, 0(t2)
  bne a1, t2, fail_value

  /* 2) Plain HLV from the same page must raise a load guest-page fault. */
  li a2, 0x5a5a
  hlv.w a2, (s0)
  li t0, 1
  bne s1, t0, fail_hlv           /* no fault taken: bug */

  /* 3) And once more with HLV.D after another HLVX, for good measure. */
  hlvx.wu a1, (s0)
  li t0, 1
  bne s1, t0, fail_hlvx
  hlv.d a2, (s0)
  li t0, 2
  bne s1, t0, fail_hlv2

  PASS

fail_hlvx:
  FAIL(2)
fail_value:
  FAIL(3)
fail_hlv:
  FAIL(4)
fail_hlv2:
  FAIL(5)

/* M-mode trap handler: count load guest-page faults and skip the instruction. */
  .align 2
  .globl trap_handler
trap_handler:
  csrr t5, mcause
  li t6, CAUSE_LOAD_GUEST_PAGE_FAULT
  bne t5, t6, unexpected
  addi s1, s1, 1
  csrr s2, mtval2
  csrr t5, mepc
  addi t5, t5, 4                 /* hlv/hlvx are 32-bit instructions */
  csrw mepc, t5
  mret
unexpected:
  FAIL(100)

  .data
  .align 4
magic:
  .word 0x13579bdf
  .word 0x2468ace0

  HYP_TABLES
