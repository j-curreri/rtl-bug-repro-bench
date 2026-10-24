/* G-stage read permission must be re-checked on a DTLB hit.
 * GPA 0xC0000000 maps (G-stage, 1 GiB) to PA 0x80000000 as execute-only.
 * HLVX.WU from it is legal and fills the DTLB; a following HLV.W to the
 * same address must raise a load guest-page fault (cause 21). */
#include "hyp.h"

#define GVA_BASE 0xC0000000

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* G-stage: identity for DRAM, execute-only alias at GPA 0xC0000000 */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 3, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A))
  csrw vsatp, zero
  HGATP_ON
  li t0, HSTATUS_SPVP
  csrs hstatus, t0
  li t0, (1 << 19)          /* clear mstatus.MXR */
  csrc mstatus, t0

  la s0, data_word
  li t0, 0x80000000
  sub s0, s0, t0
  li t0, GVA_BASE
  add s0, s0, t0            /* s0 = guest address of data_word via X-only alias */

  li s1, 0                  /* trap counter */
  li s2, 0                  /* last mcause */

  /* 1: HLVX.WU must succeed and return the data */
  hlvx.wu a1, (s0)
  bnez s1, fail1
  li t0, 0x12345678
  bne a1, t0, fail2

  /* 2: HLV.W on the same (now cached) translation must fault */
  li a2, 0
  hlv.w a2, (s0)
  li t0, 1
  bne s1, t0, fail3
  li t0, 21
  bne s2, t0, fail4
  bnez a2, fail5
  PASS
fail1: FAIL(1)
fail2: FAIL(2)
fail3: FAIL(3)
fail4: FAIL(4)
fail5: FAIL(5)

  .align 2
  .globl trap_handler
trap_handler:
  csrr s2, mcause
  addi s1, s1, 1
  li t0, 3
  bge s1, t0, 1f
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret
1: FAIL(10)

  .data
  .align 3
data_word: .word 0x12345678
  .word 0
HYP_TABLES
