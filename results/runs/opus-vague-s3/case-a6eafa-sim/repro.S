/* Bug: the G-stage U bit is not checked for the implicit accesses that a
 * VS-stage page-table walk makes. Every G-stage access counts as a U-mode
 * access, so a VS page table reached through a G-stage leaf with U=0 must
 * raise a guest-page fault (load guest-page fault, cause 21, for a load). */
#include "hyp.h"
  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* G-stage: GPA 0x80000000 -> PA 0x80000000 (U=1);
   *          GPA 0xC0000000 -> PA 0x80000000 with U=0. */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 3, 0x80000000, (G_RWX & ~PTE_U))
  /* VS-stage: VA 0x80000000 -> GPA 0x80000000 (1 GiB leaf, for code/data). */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  /* VS-stage: VA 0xC0000000 -> non-leaf pointing at l2 through the U=0 alias. */
  la t0, vs_root
  la t1, l2
  li t2, 0x40000000
  add t1, t1, t2
  srli t1, t1, 12
  slli t1, t1, 10
  ori t1, t1, PTE_V
  sd t1, (3*8)(t0)
  /* l2[0]: 2 MiB leaf -> GPA 0x80000000 */
  RAW_PTE(l2, 0, ((0x80000000 >> 12 << 10) | VS_RWX))
  HGATP_ON
  la t2, vs_root
  VSATP_ON(t2)
  li s11, 0
  ENTER_VS(vs_code)

vs_code:
  /* Sanity: a normal load via the U=1 path works. */
  la s0, data
  ld t2, 0(s0)
  bnez s11, fail_1
  /* Load via VA 0xC0000000 + offset: the walk reads l2 through a G-stage
   * leaf with U=0, which must fault with cause 21. */
  li s1, 0x80000000
  sub s0, s0, s1
  li t0, 0xC0000000
  add t0, t0, s0
  ld t2, 0(t0)
  li t5, 21
  bne s11, t5, fail_2
  ecall

fail_1: FAIL(1)
fail_2: FAIL(2)

  .globl trap_handler
  .align 2
trap_handler:
  csrr s11, mcause
  li t5, 10            /* ecall from VS: test finished */
  beq s11, t5, done
  li t5, 21
  bne s11, t5, bad
  csrr t5, mepc
  addi t5, t5, 4
  csrw mepc, t5
  mret
done:
  PASS
bad:
  FAIL(3)

  .data
  .align 12
l2: .space 4096
data: .dword 0x1234
  HYP_TABLES
