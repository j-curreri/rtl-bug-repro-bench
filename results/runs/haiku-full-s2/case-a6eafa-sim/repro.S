/* HLVX must not let the implicit VS-stage PTE read use execute-only permission.
 * Layout (all 1 GiB leaves):
 *   G-stage: gpa 0x80000000 -> PA 0x80000000, RWX (code/data, also the final data page)
 *   G-stage: gpa 0xC0000000 -> PA 0x80000000, X-only (alias that holds the VS root)
 *   VS-stage root = vs_root at gpa (PA of vs_root + 0x40000000), so it sits in the X-only alias
 *   VS-stage: vaddr 0x80000000 -> gpa 0x80000000, VS_RWX
 * The VS root PTE read is an implicit load for G-stage checks, so it must fault (load guest-page
 * fault, cause 21). HLVX only relaxes the check for the final access, not for the PTE read.
 * Correct core: trap with mcause 21 -> PASS. Buggy core: hlvx.wu completes -> FAIL. */
#include "hyp.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* G-stage tables */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 3, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A | PTE_D))
  HGATP_ON

  /* VS-stage root: gpa of vs_root inside the X-only alias */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  la t0, vs_root
  li t1, 0x40000000
  add t0, t0, t1
  VSATP_ON(t0)

  /* HLV/HLVX use hstatus.SPVP as the effective privilege (S-level guest) */
  li t0, HSTATUS_SPVP
  csrs hstatus, t0

  /* HLVX.WU from M-mode on guest address 0x80000000 */
  li a1, 0x80000000
  hlvx.wu a0, (a1)

  /* Reached only if the HLVX walk succeeded through the execute-only PTE read */
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
