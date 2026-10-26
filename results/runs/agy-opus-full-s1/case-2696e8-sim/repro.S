/* HLVX on a G-stage execute-only page must succeed; a following plain HLV
 * from the same page must raise a load guest-page fault (mcause 21). */
#include "hyp.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  li s0, 0                 /* number of guest-page faults seen */
  li s1, 0                 /* last mcause */

  /* G-stage: GPA 0x80000000 (1 GiB) -> PA 0x80000000, execute-only (U required). */
  GIGA_LEAF(g_root, 2, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A | PTE_D))
  csrw vsatp, zero         /* VS-stage bare */
  HGATP_ON
  hfence.vvma

  la s2, data_word

  /* HLVX: execute permission counts as read -> must succeed. */
  hlvx.wu a1, (s2)
  bnez s0, fail_hlvx
  li t0, 0x5a5a1234
  bne a1, t0, fail_val

  /* Plain HLV from the same page: must fault. */
  li a2, 0
  hlv.w a2, (s2)
  li t0, 1
  bne s0, t0, fail_nofault
  li t0, 21
  bne s1, t0, fail_cause
  PASS

fail_hlvx:    FAIL(1)
fail_val:     FAIL(2)
fail_nofault: FAIL(3)
fail_cause:   FAIL(4)

  .align 2
  .globl trap_handler
trap_handler:
  csrr s1, mcause
  li t0, 21
  bne s1, t0, unexpected
  addi s0, s0, 1
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret
unexpected:
  FAIL(5)

  HYP_TABLES
  .align 3
data_word: .word 0x5a5a1234
