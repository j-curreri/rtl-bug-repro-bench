#include "hyp.h"

/* G-stage: GPA 0x40000000 (1 GiB) -> PA 0x80000000, execute-only (no R).
 * HLVX may read it (needs X); a following plain HLV must raise a load
 * guest-page fault even though the translation is now cached in the DTLB. */
#define G_XONLY (PTE_V | PTE_X | PTE_U | PTE_A | PTE_D)

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  GIGA_LEAF(g_root, 1, 0x80000000, G_XONLY)
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  HGATP_ON
  csrw vsatp, zero
  li t0, HSTATUS_SPVP
  csrs hstatus, t0

  la s0, data_word
  li t0, 0x40000000
  sub s0, s0, t0              /* GPA alias of data_word (PA - 0x40000000) */
  li s1, 0                    /* fault count */

  /* HLVX: allowed through execute permission. */
  hlvx.hu a1, (s0)
  li t0, 0x1234
  bne a1, t0, fail1

  /* Plain HLV on X-only G-stage page: must fault (cause 21). */
  hlv.d a2, (s0)
  li t0, 1
  bne s1, t0, fail2
  csrr t0, mtval2
  srli t1, s0, 2
  bne t0, t1, fail3
  PASS
fail1: FAIL(1)
fail2: FAIL(2)
fail3: FAIL(3)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  li t5, 21
  bne t6, t5, bad_trap
  addi s1, s1, 1
  csrr t5, mepc
  addi t5, t5, 4
  csrw mepc, t5
  mret
bad_trap:
  FAIL(4)

  .data
  .align 3
data_word: .dword 0x1111222233331234

HYP_TABLES
