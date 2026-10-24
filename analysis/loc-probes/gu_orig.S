/* G-stage translation of VS-stage page-table accesses is always performed as a
 * U-mode access (H spec: "all memory accesses (including those made to access data
 * structures for VS-stage address translation) are considered to be user-level
 * accesses"). A G-stage leaf with U=0 that maps the VS-stage page table must
 * therefore raise a guest-page fault on the implicit PTE read. */
#include "hyp.h"

#define G_RWX_NOU (G_RWX & ~PTE_U)

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* G-stage: GPA 0x80000000 -> PA 0x80000000 (U=1), GPA 0xC0000000 -> PA 0x80000000 (U=0) */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 3, 0x80000000, G_RWX_NOU)
  /* VS-stage: VA 0x80000000 -> GPA 0x80000000 */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  HGATP_ON

  /* HLV accesses as VS (SPVP=1) */
  li t0, HSTATUS_SPVP
  csrs hstatus, t0

  /* Control: VS root reached through the U=1 alias -> load must succeed */
  la t2, vs_root
  VSATP_ON(t2)
  li s0, 0
  la t3, value
  hlv.d s1, (t3)
  bnez s0, fail_ctrl
  li t4, 0x1234567890abcdef
  bne s1, t4, fail_val

  /* Test: VS root reached through the U=0 alias -> load guest-page fault */
  la t2, vs_root
  li t1, 0x40000000
  add t2, t2, t1
  VSATP_ON(t2)
  hfence.gvma
  li s0, 0
  li s1, 0
  la t3, value
  hlv.d s1, (t3)
  li t4, 21
  bne s0, t4, fail_test
  PASS

fail_ctrl:
  FAIL(1)
fail_val:
  FAIL(2)
fail_test:
  beqz s0, 1f
  FAIL(4)
1:
  FAIL(3)

  .align 2
  .globl trap_handler
trap_handler:
  csrr s0, mcause
  li t5, 21
  bne s0, t5, 1f
  csrr t5, mepc
  addi t5, t5, 4
  csrw mepc, t5
  mret
1:
  csrr t6, mcause
  FAIL(127)

  .data
  .align 3
value: .dword 0x1234567890abcdef

  HYP_TABLES
