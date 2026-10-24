#include "test.h"
#include "hyp.h"

/*
 * Bug: implicit VS-stage PTE reads are not checked against G-stage permissions
 * when the walk was triggered by an HLVX.
 *
 * An HLVX executed with both the VS-stage (vsatp) and the G-stage (hgatp)
 * active performs a two-stage walk: the walker first translates the VS-stage
 * PTE addresses (GPA -> HPA) through the G-stage. Those PTE fetches are
 * ordinary loads for G-stage permission purposes, so if the VS-stage table
 * lives in guest-physical memory that the G-stage maps execute-only, the
 * walk must raise a load guest-page fault (cause 21).
 *
 * The buggy core instead lets the HLVX's execute permission authorize the
 * intermediate G-stage PTE reads, so the walk (and the HLVX) succeeds.
 *
 * Test:
 *  - VS-stage: vs_root[2] = 1 GiB leaf mapping GVA [2GiB,3GiB) -> same GPA, RWX.
 *  - G-stage:  4 KiB leaves via g_root (16KiB) -> g_lvl1 -> g_lvl0:
 *      load-target page mapped RWX, the VS-stage table page mapped X-only.
 *  - M-mode:  hlvx.wu from the load-target GVA.
 *
 * Correct core: load guest-page fault -> mcause=21 -> trap_handler -> PASS
 * Buggy core:   the HLVX completes -> FAIL(42)
 */

  .data
  .align 12
  load_target: .dword 0x1122334455667788
              .space 4088
  .align 12
  g_lvl0: .space 4096
  .align 12
  g_lvl1: .space 4096
  .align 14
  g_root: .space 16384
  .align 12
  vs_root: .space 4096

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* VS-stage (Sv39): 1 GiB identity leaf at top-level index 2,
   * covers GVA 0x80000000-0x83FFFFFFF, R|W|X|A|D, U=0. */
  la   t0, vs_root
  li   t1, 16            /* PTE index 2 */
  add  t0, t0, t1
  li   t1, 0x20000000    /* PPN = 0x80000000 >> 12, placed in PTE[29:10] */
  ori  t1, t1, (PTE_V|PTE_R|PTE_W|PTE_X|PTE_A|PTE_D)
  sd   t1, 0(t0)

  /* G-stage root (16 KiB table, index = GPA[40:30]): intermediate PTE -> g_lvl1 */
  la   t0, g_lvl1
  srli t0, t0, 12
  slli t0, t0, 10
  ori  t0, t0, PTE_V     /* intermediate PTE: V only, A/D/U clear */
  la   t1, g_root
  la   t2, load_target
  srli t2, t2, 30
  andi t2, t2, 0x1ff
  slli t2, t2, 3
  add  t1, t1, t2
  sd   t0, 0(t1)

  /* G-stage level 1 (index = GPA[29:21]): intermediate PTE -> g_lvl0 */
  la   t0, g_lvl0
  srli t0, t0, 12
  slli t0, t0, 10
  ori  t0, t0, PTE_V
  la   t1, g_lvl1
  la   t2, load_target
  srli t2, t2, 21
  andi t2, t2, 0x1ff
  slli t2, t2, 3
  add  t1, t1, t2
  sd   t0, 0(t1)

  /* G-stage level 0: load-target page mapped fully accessible (identity) */
  la   t0, load_target
  srli t0, t0, 12
  slli t0, t0, 10
  ori  t0, t0, (PTE_V|PTE_R|PTE_W|PTE_X|PTE_U|PTE_A|PTE_D)
  la   t1, g_lvl0
  la   t2, load_target
  srli t2, t2, 12
  andi t2, t2, 0x1ff
  slli t2, t2, 3
  add  t1, t1, t2
  sd   t0, 0(t1)

  /* G-stage level 0: the VS-stage table page mapped EXECUTE-ONLY.
   * The implicit VS-stage PTE read is an ordinary load: on a spec-compliant
   * core this must produce a load guest-page fault during the walk. */
  la   t0, vs_root
  srli t0, t0, 12
  slli t0, t0, 10
  ori  t0, t0, (PTE_V|PTE_X|PTE_U|PTE_A|PTE_D)
  la   t1, g_lvl0
  la   t2, vs_root
  srli t2, t2, 12
  andi t2, t2, 0x1ff
  slli t2, t2, 3
  add  t1, t1, t2
  sd   t0, 0(t1)

  /* enable G-stage (Sv39x4) and VS-stage (Sv39) translation */
  HGATP_ON
  la   t0, vs_root
  VSATP_ON(t0)

  /* The walk for this HLVX reads the VS-stage PTEs through the G-stage,
   * where the VS-stage table page is execute-only.  A correct core faults
   * with a load guest-page fault; the buggy one lets it complete. */
  la   t5, load_target
  hlvx.wu t3, 0(t5)

  /* reached only if the core wrongly allowed the implicit VS-stage PTE read */
  FAIL(42)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li   t1, 21           /* LOAD_GUEST_PAGE_FAULT */
  bne  t0, t1, unexpected_trap
  PASS
unexpected_trap:
  FAIL(127)
