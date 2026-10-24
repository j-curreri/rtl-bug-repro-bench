/* G-stage execute-only page: HLVX may read it, a following plain HLV load must
 * raise a load guest-page fault (cause 21) even if the translation is cached. */
#include "hyp.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* GPA 0x80000000 GiB -> PA 0x80000000, execute-only (no R/W) */
  GIGA_LEAF(g_root, 2, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A))
  HGATP_ON
  csrw vsatp, zero
  li t0, HSTATUS_SPVP
  csrs hstatus, t0
  li t0, (1 << 19)          /* mstatus.MXR = 0 */
  csrc mstatus, t0
  csrw vsstatus, zero

  li s1, 0                  /* trap count */
  la s0, target
  hlvx.hu a1, (s0)          /* allowed: X permission, populates DTLB */
  bnez s1, fail1
  li t0, 0x1234
  bne a1, t0, fail2

  hlv.d a2, (s0)            /* must fault: no R at G-stage */
  li t0, 1
  bne s1, t0, fail3
  li t0, 21
  bne s2, t0, fail4
  PASS
fail1: FAIL(1)
fail2: FAIL(2)
fail3: FAIL(3)
fail4: FAIL(4)

  .globl trap_handler
  .align 2
trap_handler:
  csrr s2, mcause
  addi s1, s1, 1
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret

  .data
  .align 3
target: .dword 0x1234
  HYP_TABLES
