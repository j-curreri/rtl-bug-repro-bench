#include "hyp.h"

/* HLVX from an execute-only G-stage page fills the DTLB; a subsequent plain HLV
 * from the same page must still raise a load guest-page fault (cause 21). */
#define CAUSE_LOAD_GUEST_PAGE_FAULT 21
#define GPA_XONLY 0xC0000000

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* G-stage: GPA 0x80000000 -> PA 0x80000000 RWX; GPA 0xC0000000 -> PA 0x80000000 X-only */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 3, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A | PTE_D))
  HGATP_ON
  csrw vsatp, zero
  li t0, HSTATUS_SPVP
  csrs hstatus, t0
  li s0, 0                 /* s0 = stage marker */
  ENTER_MODE(1, hs_code)

hs_code:
  la t2, data_word
  li t1, 0x40000000
  add t2, t2, t1           /* GPA alias in execute-only gigapage */
  li s0, 1
  hlvx.wu a0, (t2)         /* must succeed */
  li t1, 0x12345678
  bne a0, t1, fail_val
  li s0, 2
  hlv.w a1, (t2)           /* must fault with load guest-page fault */
  li s0, 3
  ecall                    /* reached only if HLV did not fault */
fail_val:
  ecall

  .align 2
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  li t5, 2
  bne s0, t5, 1f
  li t5, CAUSE_LOAD_GUEST_PAGE_FAULT
  bne t6, t5, 2f
  PASS
1:
  FAIL(1)
2:
  FAIL(2)

  .data
  .align 3
data_word: .word 0x12345678
  .word 0

HYP_TABLES
