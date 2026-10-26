#include "hyp.h"

/* A VS-stage 2 MiB leaf maps VA 0x180010 to GPA 0x40380010 (GPA[29:21] from the PTE, VA[20:0] kept).
 * The G-stage has no mapping for GPA 0x40000000..0x7fffffff, so the load must raise a load guest-page
 * fault whose mtval2 (GPA >> 2) is 0x40380010 >> 2. The buggy core takes GPA bits 20:19 from the
 * PTE instead of the VA, which makes mtval2 differ. */

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* G-stage: identity 1 GiB leaf for DRAM at root index 2 (GPA 0x80000000). Index 1 stays invalid. */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  HGATP_ON

  /* VS-stage: vs_root[2] = identity 1 GiB leaf for DRAM (code and VS tables). */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)

  /* vs_root[0] -> vs_l1 (non-leaf pointer). */
  la t0, vs_l1
  srli t0, t0, 12
  slli t0, t0, 10
  ori t0, t0, PTE_V
  la t1, vs_root
  sd t0, 0(t1)

  /* vs_l1[0] = 2 MiB leaf mapping to GPA 0x40200000. */
  li t0, 0x40200
  slli t0, t0, 10
  ori t0, t0, VS_RWX
  la t1, vs_l1
  sd t0, 0(t1)

  la t2, vs_root
  VSATP_ON(t2)

  ENTER_VS(vs_code)

  .align 2
vs_code:
  li t0, 0x180010
  ld t1, 0(t0)
  /* Not reached on a correct core: the load must fault. */
  FAIL(2)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 21                  /* load guest-page fault */
  bne t0, t1, 1f
  csrr t0, mtval
  li t1, 0x180010
  bne t0, t1, 1f
  csrr t0, mtval2
  li t1, (0x40380010 >> 2)
  bne t0, t1, 1f
  PASS
1:
  FAIL(1)

  HYP_TABLES
  .align 12
vs_l1: .space 4096
