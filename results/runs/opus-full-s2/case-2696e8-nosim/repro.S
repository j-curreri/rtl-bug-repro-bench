#include "hyp.h"

/* G-stage maps the DRAM gigapage execute-only (no R). HLVX from that page is
 * legal; a following plain HLV.W must raise a load guest-page fault (cause 21)
 * even though the HLVX already filled the DTLB. */

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  csrw vsatp, zero              /* VS-stage bare: only G-stage translates */
  csrw hstatus, zero            /* SPVP=0 -> HLV acts as VU access */
  li t0, MSTATUS_GVA | MSTATUS_MPV
  csrc mstatus, t0
  /* GPA 0x80000000 -> PA 0x80000000, X only (plus U/A/D) */
  GIGA_LEAF(g_root, 2, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A | PTE_D))
  fence
  HGATP_ON

  la s0, target
  li s1, 0                      /* trap count */
  li s2, 0                      /* last mcause */

  hlvx.wu a1, (s0)              /* must succeed */
  bnez s1, fail_hlvx
  li t0, 0x1234abcd
  bne a1, t0, fail_hlvx_val

  nop; nop; nop; nop
  hlv.w a2, (s0)                /* must fault with load guest-page fault */
  li t0, 1
  bne s1, t0, fail_hlv
  li t0, 21
  bne s2, t0, fail_cause
  PASS

fail_hlvx:     FAIL(1)
fail_hlvx_val: FAIL(2)
fail_hlv:      FAIL(3)
fail_cause:    FAIL(4)

  .align 2
  .globl trap_handler
trap_handler:
  csrr s2, mcause
  bltz s2, 1f                   /* unexpected interrupt */
  addi s1, s1, 1
  csrr t0, mepc
  addi t0, t0, 4                /* hlv/hlvx are 4-byte instructions */
  csrw mepc, t0
  mret
1: FAIL(5)

  .data
  .align 3
target: .word 0x1234abcd
  .align 3

HYP_TABLES
