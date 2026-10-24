#include "hyp.h"

/*
 * Bug: HLVX succeeds even when the VS-stage page table itself lives in
 * guest-physical memory that the G-stage maps execute-only.
 *
 * The implicit read of a VS-stage PTE is an ordinary load for G-stage
 * permission checks, so the walk must raise a load guest-page fault
 * (mcause = 21, mstatus.GVA = 1 when the trap is taken in M-mode).
 *
 * Setup (M-mode):
 *   G-stage (Sv39x4), 16 KiB root g_root (hgatp.ppn = PA >> 14):
 *     index 1: GPA 0x4000_0000-0x7FFF_FFFF -> PA 0x8000_0000 (1 GiB leaf),
 *               execute-only (V|X|A|D)                    <- bug trigger
 *               (vs_root physically lives in this window, at 0x8000_8000)
 *     index 2: GPA 0x8000_0000-0xBFFF_FFFF -> PA 0x8000_0000, RWX (identity)
 *   VS-stage (Sv39), root vs_root (PA 0x8000_8000, i.e. GPA 0x4000_8000):
 *     index 2: VMA 0x8000_0000-0xBFFF_FFFF -> PA 0x8000_0000, RWX+U
 *
 * Then mret into S-mode (HS) and execute:  hlvx.hu t3, (0x80000000)
 *   - correct core: the implicit G-stage PTE fetch of the VS-stage PTE
 *     (GPA 0x4000_8008, an ordinary load) hits the execute-only 1 GiB G PTE
 *     -> load guest-page fault -> the M-mode handler records it, mrets past
 *     the hlvx; S-mode then PASSes.
 *   - buggy core: the walk (wrongly) grants execute-as-read for the implicit
 *     VS PTE load, no fault is raised, hlvx completes; S-mode sees the
 *     missing trap and FAILs.
 */

HYP_TABLES

  .data
trap_ok: .dword 0

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* G-stage: index 2, 1 GiB leaf, GPA 0x80000000 -> PA 0x80000000 (identity)
   * for our code/data.  U=1 is required for S-mode accesses on this core. */
  la t0, g_root
  li t1, 2*8
  add t0, t0, t1
  li t1, ((0x80000000 >> 12) << 10) | G_RWX
  sd t1, 0(t0)

  /* G-stage: index 1, 1 GiB leaf, GPA 0x40000000 -> PA 0x80000000.
   * The physical page holding vs_root (0x80008000) lies inside this window,
   * so every implicit load of a VS-stage PTE hits this execute-only G PTE.
   * (ppn = 0x80000 is 1 GiB aligned, as required for a level-2 leaf PTE.) */
  la t0, g_root
  li t1, 1*8
  add t0, t0, t1
  li t1, ((0x80000000 >> 12) << 10) | (PTE_V | PTE_X | PTE_A | PTE_D)
  sd t1, 0(t0)

  /* VS-stage: index 2, VMA 0x80000000 -> PA 0x80000000, RWX.
   * U=1 because hstatus.SPVP = 0 (VS privilege is U). */
  la t0, vs_root
  li t1, 2*8
  add t0, t0, t1
  li t1, ((0x80000000 >> 12) << 10) | (PTE_V | PTE_R | PTE_W | PTE_X | PTE_U | PTE_A | PTE_D)
  sd t1, 0(t0)

  /* VS-stage root lives at GPA 0x4000_0000 | (PA & 0x3FFFFFFF). */
  la t2, vs_root
  li t3, 0x3ffffffff
  and t2, t2, t3
  li t3, 0x40000000
  or t2, t2, t3
  VSATP_ON(t2)

  /* G-stage (Sv39x4): the 16 KiB root sits at g_root, so hgatp.ppn = PA >> 14. */
  la t0, g_root
  srli t0, t0, 14
  li t1, SATP_SV39
  or t0, t0, t1
  csrw hgatp, t0
  hfence.gvma

  /* run the test in S-mode (HS) */
  ENTER_MODE(1, s_test)

s_test:
  li t3, -1                  /* sentinel: not written if the hlvx traps */
  li t4, 0x80000000
hlvx_inst:
  hlvx.hu t3, (t4)           /* correct core: traps here */
  la t0, trap_ok
  lw t0, 0(t0)
  beqz t0, s_fail
  li t5, -1
  bne t3, t5, s_fail
  PASS
s_fail:
  FAIL(1)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  li t5, 21                  /* load guest-page fault */
  bne t6, t5, 2f
  csrr t5, mstatus
  srli t5, t5, 38
  andi t5, t5, 1             /* mstatus.GVA must be set */
  beqz t5, 2f
  la t5, hlvx_inst           /* mepc must be the hlvx itself */
  csrr t6, mepc
  bne t6, t5, 2f
  /* the expected fault: record it and resume past the hlvx */
  la t5, trap_ok
  li t1, 1
  sd t1, 0(t5)
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret
2:
  FAIL(127)
