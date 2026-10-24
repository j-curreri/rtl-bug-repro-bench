#include "test.h"
#include "hyp.h"

/* Repro: after an HLVX hits a G-stage execute-only page, a plain load from the
 * same page must raise a load guest-page fault (only HLVX may treat the
 * execute permission of a G-stage PTE as read permission).
 *
 * The MMU caches the G-stage PTE in the DTLB when the HLVX walk completes.
 * On a DTLB hit, the load path must re-check the G-stage read permission
 * (pte.r, or pte.x for HLVX/mxr). On the buggy core that check is missing,
 * so the plain load succeeds.
 *
 * Everything runs in M-mode so there are no mode switches and no TLB
 * flushes between the two accesses:
 *  - G-stage (Sv39x4) table: one 1 GiB execute-only leaf, root idx 2,
 *    mapping GPA[0x8000_0000, +1 GiB) -> PA[0x8000_0000, +1 GiB) (identity).
 *  - MPRV=1, MPP=M, MPV=1: M-mode loads/stores are virtualized, i.e. they
 *    undergo G-stage translation (spec-correct way to G-stage-load from M).
 *  - hlvx.wu on the execute-only page: succeeds (execute permission),
 *    populates the G-stage DTLB entry.
 *  - plain ld on the same page: must fault (load guest-page fault, cause 21
 *    in this core) on a correct core; on the buggy core the DTLB hit path
 *    skips the G-stage load-permission check and the load succeeds.
 *  - ecall: M-mode ecall (cause 11) -> handler decides.
 */

  .section .data
  HYP_TABLES
  .align 12
guest_page: .space 4096

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* G-stage: 1 GiB execute-only leaf at root index 0x80000000 >> 30 = 2 */
  GIGA_LEAF(g_root, 2, 0x80000000, PTE_V | PTE_X | PTE_U | PTE_A | PTE_D)

  /* enable G-stage translation (hgatp = PPN | MODE_SV39) */
  la   t0, g_root
  srli t0, t0, 12
  li   t1, 0x8000000000000000
  or   t0, t0, t1
  csrw hgatp, t0
  hfence.gvma

  la   t0, trap_handler
  csrw mtvec, t0

  /* virtualized M-mode accesses: MPP=M, MPRV=1, MPV=1 */
  li   t0, 0x1800
  csrs mstatus, t0
  li   t0, 0x2000000000020000
  csrs mstatus, t0

  la a0, guest_page          /* GVA == PA under the identity 1 GiB mapping */
  hlvx.wu t3, 0(a0)          /* execute access: allowed (X=1); caches the
                               G-stage PTE in the DTLB */
  ld t4, 0(a0)               /* correct core: load guest-page fault (21).
                               buggy core: DTLB hit skips the G-load check */
  ecall                      /* M-mode ecall: mcause = 11 */

  .align 2
trap_handler:
  li   t0, 0x2000000000020000
  csrc mstatus, t0           /* drop MPRV/MPV before any further memory access */
  csrr t0, mcause
  li   t1, 21                /* load guest-page fault: expected on good core */
  beq  t0, t1, pass_expected
  li   t1, 11                /* M-mode ecall: the load did not fault -> bug */
  beq  t0, t1, fail_no_fault
  FAIL(2)
pass_expected:
  PASS
fail_no_fault:
  FAIL(1)
