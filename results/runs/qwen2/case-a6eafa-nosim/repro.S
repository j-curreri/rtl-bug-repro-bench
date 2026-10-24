/* Reproducer for: HLVX succeeds even when the VS-stage page table itself lives in
 * guest-physical memory that the G-stage maps execute-only.  The implicit read of a
 * VS-stage PTE is an ordinary load for G-stage permission checks, so the walk must
 * raise a load guest-page fault.
 *
 * Setup (two-stage translation for an HLVX issued in HS-mode, V=0):
 *   - G-stage  (Sv39x4, hgatp=g_root): a 1GiB leaf at g_root[2] that maps the whole
 *     DRAM window GPA [0x8000_0000, 0xC000_0000) as EXECUTE-ONLY (X=1, R=0, W=0).
 *     This window contains both the VS-stage table (vs_root) and the data.  Any
 *     implicit PTE read inside it is therefore a load into execute-only G memory.
 *   - VS-stage (Sv39, vsatp=vs_root): a 1GiB leaf at vs_root[2] mapping the same VA
 *     window to the same GPAs, marked executable so the (buggy) walk can continue
 *     past the VS PTE once the G check is (incorrectly) passed.
 *
 * Outcome:
 *   - Correct core: the first implicit read of the VS-stage PTE hits the X-only G PTE
 *     and raises LOAD_GUEST_PAGE_FAULT (mcause==21) -> trap handler records it -> PASS.
 *   - Buggy core:  the G permission check lets the X-only PTE read through, the walk
 *     completes, no trap -> FAIL.
 */
#include "test.h"
#include "hyp.h"

  /* G-stage leaf PTE flags: execute-only, valid, accessed, user.  V|X|A|U. */
  #define G_XONLY   (PTE_V | PTE_X | PTE_A | PTE_U)
  /* VS-stage leaf PTE flags: readable/writable/executable, valid, accessed, dirty,
   * U=0 so HS-mode may touch it without SUM.  V|R|W|X|A|D. */
  #define VS_LEAF   (PTE_V | PTE_R | PTE_W | PTE_X | PTE_A | PTE_D)

  HYP_TABLES

  .data
  .align 12
data_page:
  .space 0x40

  .bss
  .align 3
  .globl got_trap
got_trap:
  .space 8

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* G-stage root (Sv39x4): index 2 == GPA[40:30]==2 -> the 1GiB window
   * [0x8000_0000, 0xC000_0000) that holds the VS table AND the data.  Map it
   * execute-only so the implicit PTE read there must fault on a good core. */
  GIGA_LEAF(g_root, 2, 0x80000000, G_XONLY)

  /* VS-stage root (Sv39): index 2 == VA[38:30]==2 -> [0x8000_0000, 0xC000_0000). */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_LEAF)

  /* Enable G-stage (hgatp=g_root) and VS-stage (vsatp=vs_root). */
  HGATP_ON
  la t0, vs_root
  VSATP_ON(t0)

  /* Known value the HLVX will load. */
  li t1, 0xcafef00d
  la t0, data_page
  sd t1, 0(t0)

  /* mret into HS-mode (V=0, S-privilege): clear MPP(12:11) and MPV(39), set MPP=S. */
  li t0, 3 << 11
  csrc mstatus, t0
  li t0, 1 << 39
  csrc mstatus, t0
  li t0, 1 << 11
  csrs mstatus, t0
  la t0, hs_body
  csrw mepc, t0
  mret

hs_body:
  /* HS-mode (V=0, S).  HLVX from a VS virtual address whose VS-stage PTE resides in
   * G-stage execute-only memory.  A spec-correct core faults (load guest-page fault)
   * on the implicit PTE read; the buggy core completes the walk. */
  li a0, 0
  la a1, data_page
  hlvx.wu a0, 0(a1)

check:
  /* Reached here either because the HLVX completed (bug) or because the trap handler
   * mret'd back here after the expected guest-page fault (correct). */
  la t0, got_trap
  ld t1, 0(t0)
  beqz t1, is_buggy
  PASS
is_buggy:
  FAIL(2)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  li t5, 21              /* LOAD_GUEST_PAGE_FAULT */
  bne t6, t5, unhandled
  /* Expected load guest-page fault: record it and resume past the HLVX. */
  li t0, 1
  la t1, got_trap
  sd t0, 0(t1)
  la t0, check
  csrw mepc, t0
  mret
unhandled:
  FAIL(127)
