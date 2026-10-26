/* Reproducer: HLVX must not relax the G-stage permission check for the implicit
 * read of a VS-stage PTE. That implicit read is an ordinary load, so when the VS
 * root lives in a guest-physical page that G-stage maps execute-only, the walk must
 * raise a load guest-page fault (mcause 21). */
#include "hyp.h"

#define G_X_ONLY (PTE_V | PTE_U | PTE_X | PTE_A | PTE_D)  /* no R: execute-only */

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* G-stage: GPA 0x80000000..0xBFFFFFFF -> same PA, execute-only. */
  GIGA_LEAF(g_root, 2, 0x80000000, G_X_ONLY)

  /* VS-stage: VA 0x80000000..0xBFFFFFFF -> GPA same, RWX. The VS root (vs_root)
   * is therefore in guest-physical memory that G-stage maps execute-only. */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)

  la t2, vs_root
  VSATP_ON(t2)
  HGATP_ON

  /* Effective privilege for HLVX is S, so VS-stage U=0 leaves are accessible. */
  li t0, HSTATUS_SPVP
  csrs hstatus, t0

  /* Run the HLVX from HS-mode (HLVX is illegal in VS-mode). */
  ENTER_MODE(1, hs_code)

  .globl hs_code
hs_code:
  la t2, guest_data
  hlvx.wu t1, (t2)
  /* Walk did not fault: the bug is present. */
  FAIL(1)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 21                 /* load guest-page fault */
  bne t0, t1, 1f
  PASS
1:
  FAIL(2)

  HYP_TABLES

  .globl guest_data
  .align 3
guest_data: .dword 0x1234abcd
