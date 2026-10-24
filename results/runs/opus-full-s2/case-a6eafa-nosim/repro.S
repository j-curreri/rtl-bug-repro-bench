/* HLVX must not bypass G-stage read permission for the implicit VS-stage PTE read.
 * vsatp root lives at guest-physical 0xC0000000+off, which the G-stage maps
 * execute-only. The walk's PTE fetch is an ordinary load for G-stage checks,
 * so HLVX.WU must raise a load guest-page fault (mcause 21). */
#include "hyp.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* G-stage: GPA 0x80000000 -> PA 0x80000000 RWX; GPA 0xC0000000 -> PA 0x80000000 X only */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 3, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A))
  /* VS-stage: VA 0x80000000 -> GPA 0x80000000 */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  HGATP_ON
  /* vsatp root = GPA alias of vs_root through the execute-only G-stage window */
  la t2, vs_root
  li t1, 0x40000000
  add t2, t2, t1
  VSATP_ON(t2)
  li t0, HSTATUS_SPVP
  csrs hstatus, t0
  ENTER_MODE(1, hs_code)

  .align 2
hs_code:
  la a1, target
  hlvx.wu a2, (a1)
  FAIL(1)

  .align 2
target:
  nop

  .align 2
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  li t5, 21
  bne t6, t5, 1f
  PASS
1:
  FAIL(2)

  HYP_TABLES
