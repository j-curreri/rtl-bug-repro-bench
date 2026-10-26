#include "test.h"
#include "hyp.h"

  .globl trap_handler
trap_handler:
  csrr t6, mcause
  li t5, 21 /* load guest-page fault */
  bne t6, t5, bad_trap
  PASS

bad_trap:
  FAIL(2)

  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Set hstatus.SPVP = 1 (VS-mode) */
  li t0, HSTATUS_SPVP
  csrs hstatus, t0

  /* Map GPA gigapage 1 (containing vs_root) to HPA gigapage 2 as execute-only:
   * PTE_V | PTE_X | PTE_U | PTE_A | PTE_D (no PTE_R, no PTE_W). */
  GIGA_LEAF(g_root, 1, 0x80000000, PTE_V | PTE_X | PTE_U | PTE_A | PTE_D)

  /* Map GPA gigapage 2 to HPA gigapage 2 as RWX */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)

  /* In vs_root, map GVA gigapage 2 to GPA gigapage 2 */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)

  /* Enable G-stage translation */
  HGATP_ON

  /* Enable VS-stage translation pointing to vs_root via GPA in gigapage 1 */
  la t0, vs_root
  li t1, 0x40000000
  sub t0, t0, t1
  VSATP_ON(t0)

  /* Target address in gigapage 2 */
  la a2, target_data
  hlvx.wu a1, (a2)

  /* On buggy core, HLVX succeeds without raising a load guest-page fault */
  FAIL(1)

  .data
  .align 3
target_data:
  .dword 0x12345678abcdef01

HYP_TABLES
