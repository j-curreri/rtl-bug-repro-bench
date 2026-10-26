/* Reproducer: VS-stage non-leaf PTE pointing outside the guest-physical space.
 * The spec requires a load guest-page fault (cause 21); the buggy core reports a
 * load page fault (cause 13) instead. */
#include "test.h"
#include "hyp.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* G-stage: identity 1 GiB leaf for GPA/PA 0x80000000 (code, stack, page tables). */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  HGATP_ON

  /* VS-stage: identity leaf for 0x80000000 so VS-mode can fetch and use the stack. */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)

  /* VS-stage: VA 0x40000000 (vs_root[1]) is a non-leaf pointer whose PPN has bit 29 set,
   * i.e. the next-level table address lies outside the 41-bit guest-physical space. */
  la t2, vs_root
  srli t2, t2, 12
  slli t2, t2, 10
  li t3, ((1 << 39) | PTE_V)
  or t2, t2, t3
  la t0, vs_root
  sd t2, 8(t0)

  la t2, vs_root
  VSATP_ON(t2)

  ENTER_VS(vs_entry)

vs_entry:
  li t2, 0x40000000
  ld t3, 0(t2)
  /* Not reached: the load must fault. */
  FAIL(1)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 21
  bne t0, t1, 1f
  PASS
1:
  FAIL(2)

  HYP_TABLES
