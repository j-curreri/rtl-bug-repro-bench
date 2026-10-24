/* HLV.W must honour G-stage R permission even when the G-stage translation is
 * already cached in the DTLB by a preceding HLVX (which may read X-only pages). */
#include "hyp.h"

#define CAUSE_LOAD_GUEST_PAGE_FAULT 21

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* G-stage: GPA 0x80000000 (1 GiB) -> PA 0x80000000, execute-only (no R/W). */
  GIGA_LEAF(g_root, 2, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A | PTE_D))
  HGATP_ON
  csrw vsatp, zero                 /* VS-stage bare: GVA == GPA */
  hfence.vvma
  li t0, HSTATUS_SPVP              /* HLV accesses as VS-mode */
  csrs hstatus, t0
  li s1, 0                         /* guest-page-fault counter */
  ENTER_MODE(1, hs_code)

hs_code:
  la a1, data_word
  li a3, 0x5a5aa5a5
  /* HLVX may read an execute-only G-stage page: must succeed. */
  hlvx.wu a2, (a1)
  bne a2, a3, fail_hlvx
  /* Plain HLV on the same page must raise a load guest-page fault. */
  li a2, 0
hlv_insn:
  hlv.w a2, (a1)
  li t0, 1
  bne s1, t0, fail_nofault
  ecall                            /* back to M-mode to finish */

fail_hlvx:
  ecall
fail_nofault:
  ecall

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, CAUSE_LOAD_GUEST_PAGE_FAULT
  bne t0, t1, 1f
  csrr t0, mepc
  la t1, hlv_insn
  bne t0, t1, 9f
  addi s1, s1, 1
  addi t0, t0, 4
  csrw mepc, t0
  mret
1:
  li t1, 9                         /* ecall from S-mode */
  bne t0, t1, 9f
  csrr t0, mepc
  la t1, fail_hlvx
  beq t0, t1, 2f
  la t1, fail_nofault
  beq t0, t1, 3f
  PASS
2:
  FAIL(2)
3:
  FAIL(3)
9:
  FAIL(9)

  .data
  .align 3
data_word: .word 0x5a5aa5a5

HYP_TABLES
