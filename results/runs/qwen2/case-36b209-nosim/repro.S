/* repro.S — reproducer for the CVA6 two-stage-translation exception-cause bug.
 *
 * Bug: in VS-mode with two-stage translation, a load whose VS-stage walk reaches a
 *       non-leaf PTE whose PPN points outside the guest-physical address space
 *       (PTE bits 63:41 not all zero) is reported with the wrong exception cause.
 *       The spec requires a guest-page fault (cause 21, LOAD_GUEST_PAGE_FAULT); the
 *       buggy core reports a supervisor load page fault (cause 13, LOAD_PAGE_FAULT).
 *
 * How it is triggered:
 *   - G-stage (Sv39x4): one 1 GiB identity leaf mapping GPA[2GiB,3GiB) -> PA, so that
 *     the VS-stage tables and the code (all in DRAM at 0x8000_0000, i.e. in
 *     [2GiB,3GiB)) are reachable.
 *   - VS-stage (Sv39):
 *       - index 2 (VA[2GiB,3GiB)): 1 GiB identity leaf -> code + data reachable.
 *       - index 1 (VA[1GiB,2GiB)): a VALID NON-LEAF PTE (V=1, R=X=0, A=D=U=0) whose
 *         PPN has bit 43 set, i.e. PTE bits 63:41 are not all zero -> out of range.
 *   - Enable G-stage (hgatp) and VS-stage (vsatp), mret into VS-mode (V=1, S-priv).
 *
 *   In VS-mode we load from VA = 0x4000_0000 (VS-stage index 1). The VS-stage walk
 *   reads that non-leaf PTE and sees the out-of-range PPN -> fault.
 *
 * medeleg/hedeleg are left 0, so the fault is taken to M-mode regardless of cause;
 * trap_handler reads mcause: 21 -> PASS (correct core), anything else -> FAIL
 * (the buggy core reports 13).
 */
#include "test.h"
#include "hyp.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* G-stage: 1 GiB identity leaf covering the whole DRAM region. */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)

  /* VS-stage index 2: 1 GiB identity leaf so the code/data is reachable in VS-mode. */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)

  /* VS-stage index 1: valid non-leaf PTE with PPN = 2^43 (PTE bit 53 set) -> points
   * outside the guest-physical address space (PTE bits 63:41 not all zero). */
  RAW_PTE(vs_root, 1, 0x0020000000000001)

  /* Enable G-stage then VS-stage translation. */
  HGATP_ON
  la t0, vs_root
  VSATP_ON(t0)

  /* mret into VS-mode (V=1, S-privilege). */
  ENTER_VS(vs_body)

vs_body:
  li a0, 0x40000000          /* VA in the VS-stage index-1 (out-of-range) range */
  ld a1, 0(a0)              /* VS-stage walk hits the out-of-range non-leaf PTE */
  FAIL(99)                  /* not expected: the load must fault */

  .align 2
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  li t0, 21                 /* riscv::LOAD_GUEST_PAGE_FAULT */
  bne t6, t0, not_guest_fault
  PASS                      /* correct core: reported as a guest-page fault */
not_guest_fault:
  /* buggy core reports a supervisor load page fault (cause 13), or an unexpected
   * trap was taken: fail, encoding the observed mcause for diagnosis. */
  slli a0, t6, 1
  li t0, 1
  or a0, a0, t0
  j _halt

HYP_TABLES
