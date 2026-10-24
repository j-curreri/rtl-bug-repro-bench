/* Bug: G-stage U bit is not checked for implicit VS-stage page-table accesses.
 *
 * H spec: "For G-stage address translation, all memory accesses (including those
 * made to access data structures for VS-stage address translation) are considered
 * to be user-level accesses", so a G-stage leaf with U=0 must raise a guest-page
 * fault when the VS-stage walker reads a page table through it.
 *
 * Setup:
 *   G-stage  GPA 0x80000000 (idx 2) -> PA 0x80000000, RWX+U   (code/data)
 *            GPA 0xC0000000 (idx 3) -> PA 0x80000000, RWX, U=0 (alias)
 *   VS-stage root = vs_root accessed through the U=0 alias GPA (vs_root + 1 GiB)
 *            VA 0x80000000 (idx 2) -> GPA 0x80000000
 * The final GPA of every access is the good mapping; only the implicit read of
 * the VS root goes through the U=0 G-stage leaf.
 *
 * Test A: HS-mode HLV.D (data path)  -> must raise load guest-page fault (21).
 * Test B: enter VS-mode (fetch path) -> must raise instr guest-page fault (20).
 * Each access may only trap with its guest-page-fault cause, and at least one
 * of them must trap. The buggy core raises neither.
 */
#include "hyp.h"

#define CAUSE_ECALL_HS     9
#define CAUSE_ECALL_VS     10
#define CAUSE_FETCH_GPF    20
#define CAUSE_LOAD_GPF     21

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 3, 0x80000000, (G_RWX & ~PTE_U))
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  HGATP_ON
  /* vsatp root = GPA of vs_root through the U=0 alias */
  la t2, vs_root
  li t0, 0x40000000
  add t2, t2, t0
  VSATP_ON(t2)
  /* HLV accesses as VS-mode (supervisor) */
  li t0, HSTATUS_SPVP
  csrs hstatus, t0
  li s0, 0                      /* number of guest-page faults seen */

  /* ---- Test A: HLV.D from HS-mode ---- */
  la s10, 1f
  li s11, -1
  li t0, MSTATUS_MPV
  csrc mstatus, t0
  ENTER_MODE(1, 2f)
2:
  la t1, scratch
  hlv.d a2, (t1)
  ecall
1:
  li t0, CAUSE_LOAD_GPF
  beq s11, t0, 3f
  li t0, CAUSE_ECALL_HS
  bne s11, t0, fail_a
  j 4f
3:
  addi s0, s0, 1
4:

  /* ---- Test B: instruction fetch in VS-mode ---- */
  la s10, 1f
  li s11, -1
  ENTER_VS(2f)
2:
  ecall
1:
  li t0, CAUSE_FETCH_GPF
  beq s11, t0, 3f
  li t0, CAUSE_ECALL_VS
  bne s11, t0, fail_b
  j 4f
3:
  addi s0, s0, 1
4:

  beqz s0, fail_nofault
  PASS
fail_nofault:
  FAIL(1)
fail_a:
  FAIL(2)
fail_b:
  FAIL(3)

/* Every trap lands in M-mode: record mcause and resume at the continuation in s10. */
  .align 2
  .globl trap_handler
trap_handler:
  csrr s11, mcause
  jr s10

  .data
  .align 4
scratch: .dword 0
HYP_TABLES
