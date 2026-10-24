/* Repro: HLVX must raise a load guest-page fault when the VS-stage PTE it
 * implicitly reads lives in guest-physical memory the G-stage maps
 * execute-only.
 *
 * Layout (this core's Sv39x4 G-stage has a 41-bit GPA and 1 GiB root
 * windows, so the G root index is GPA>>30; each root entry then fans out
 * through one 4 MiB middle table and one 4 KiB-leaf bottom table):
 *
 *   GPA 0x2_0000_0000  page holding the VS root PTEs  -> PA(vs_root), X-only
 *   GPA 0x3_0000_0000  page holding the VS mid PTEs   -> PA(vs_t1),  R|W|X
 *   GPA 0x4_0000_0000  page holding the VS bot PTEs   -> PA(vs_t2),  R|W|X
 *   GPA 0x8_0000_0000  final "instruction" page       -> PA 0x8000_0000, R|W|X
 *
 * VS-stage (Sv39) tables:
 *   vs_root[0] = 0x2_0000_0000 (V only, pointer to vs_t1)
 *   vs_t1[0]   = 0x3_0000_0000 (V only, pointer to vs_t2)
 *   vs_t2[1]   = 0x8_0000_0000 | V|A|D|X|W|R   (4 KiB leaf for VA 0x1000)
 *
 * The VS walk for VA 0x1000 must read the PTE vs_root[0] from GPA
 * 0x2_0000_0000.  That implicit PTE load is a plain load, and the G-stage
 * PTE covering that GPA lacks the R bit, so a correct core raises a load
 * guest-page fault (scause/mcause 21) on the HLVX.  The buggy core skips
 * the G-stage R check for the implicit VS PTE read, lets the walk finish
 * and commits the HLVX instead, so the test then fails.
 */
#include "hyp.h"

  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* ---------- G-stage tables: GPA -> PA ---------- */

  /* g_root[8]  -> g_t1a   (root window of GPA 0x2_0000_0000) */
  la  t0, g_t1a
  ori t0, t0, PTE_V
  la  t1, g_root
  sd  t0, 8 * 8(t1)

  /* g_t1a[0] -> g_t2a */
  la  t0, g_t2a
  ori t0, t0, PTE_V
  la  t1, g_t1a
  sd  t0, 0(t1)

  /* g_t2a[0] = X-only 4K leaf over the GPA page holding the VS root PTE.
   * This PTE is the one the G-stage must treat as a load: R is missing. */
  la  t0, vs_root
  ori t0, t0, (PTE_V | PTE_X | PTE_U | PTE_A)
  la  t1, g_t2a
  sd  t0, 0(t1)

  /* g_root[12] -> g_t1b  (root window of GPA 0x3_0000_0000) */
  la  t0, g_t1b
  ori t0, t0, PTE_V
  la  t1, g_root
  sd  t0, 12 * 8(t1)

  /* g_t1b[0] -> g_t2b */
  la  t0, g_t2b
  ori t0, t0, PTE_V
  la  t1, g_t1b
  sd  t0, 0(t1)

  /* g_t2b[0] = RWX 4K leaf -> PA(vs_t1) */
  la  t0, vs_t1
  ori t0, t0, G_RWX
  la  t1, g_t2b
  sd  t0, 0(t1)

  /* g_root[16] -> g_t1c  (root window of GPA 0x4_0000_0000) */
  la  t0, g_t1c
  ori t0, t0, PTE_V
  la  t1, g_root
  sd  t0, 16 * 8(t1)

  /* g_t1c[0] -> g_t2c */
  la  t0, g_t2c
  ori t0, t0, PTE_V
  la  t1, g_t1c
  sd  t0, 0(t1)

  /* g_t2c[0] = RWX 4K leaf -> PA(vs_t2) */
  la  t0, vs_t2
  ori t0, t0, G_RWX
  la  t1, g_t2c
  sd  t0, 0(t1)

  /* g_root[32] -> g_t1d  (root window of GPA 0x8_0000_0000) */
  la  t0, g_t1d
  ori t0, t0, PTE_V
  la  t1, g_root
  sd  t0, 32 * 8(t1)

  /* g_t1d[0] -> g_t2d */
  la  t0, g_t2d
  ori t0, t0, PTE_V
  la  t1, g_t1d
  sd  t0, 0(t1)

  /* g_t2d[0] = RWX 4K leaf -> PA 0x8000_0000 (valid DRAM page) */
  li  t0, 0x80000000
  ori t0, t0, G_RWX
  la  t1, g_t2d
  sd  t0, 0(t1)

  /* ---------- VS-stage tables: VA -> GPA ---------- */

  /* vs_root[0]: pointer to vs_t1, GPA of vs_t1 = 0x3_0000_0000 */
  li  t0, 0x30000000
  ori t0, t0, PTE_V
  la  t1, vs_root
  sd  t0, 0(t1)

  /* vs_t1[0]: pointer to vs_t2, GPA of vs_t2 = 0x4_0000_0000 */
  li  t0, 0x40000000
  ori t0, t0, PTE_V
  la  t1, vs_t1
  sd  t0, 0(t1)

  /* vs_t2[1]: 4 KiB leaf, VA [0x1000,0x2000) -> GPA 0x8_0000_0000 */
  li  t0, 0x80000000
  ori t0, t0, VS_RWX
  la  t1, vs_t2
  sd  t0, 8(t1)

  /* ---------- enable both translation stages ---------- */

  HGATP_ON
  la  t3, vs_root
  VSATP_ON(t3)

  /* ---------- run the HLVX in S-mode (V=0) ---------- */

  ENTER_MODE(1, s_entry)

s_entry:
  .align 2
  li  t2, 0x1000
  /* Guest-physical translation of this VA reads vs_root[0] from GPA
   * 0x2_0000_0000, which the G-stage maps execute-only.  The implicit PTE
   * load must raise a load guest-page fault (cause 21). */
hlvx_pc:
  hlvx a1, 0(t2)
  /* If we get here the HLVX did not trap: G-stage permission check on the
   * implicit VS PTE load was skipped -> bug. */
  FAIL(1)

/* M-mode trap handler: the S-mode (V=0) fault is not delegated, so it is
 * taken in M-mode.  Expect mcause == 21 (load guest-page fault) at hlvx_pc. */
  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li  t1, 21
  bne t0, t1, trap_handler_bad
  csrr t0, mepc
  la  t1, hlvx_pc
  bne t0, t1, trap_handler_bad
  PASS
trap_handler_bad:
  FAIL(3)

  .data
  HYP_TABLES

  .align 12
g_t1a: .space 4096
g_t1b: .space 4096
g_t1c: .space 4096
g_t1d: .space 4096
g_t2a: .space 4096
g_t2b: .space 4096
g_t2c: .space 4096
g_t2d: .space 4096
vs_t1: .space 4096
vs_t2: .space 4096
