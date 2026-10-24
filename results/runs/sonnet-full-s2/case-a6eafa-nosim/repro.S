#include "harness/hyp.h"

#define G_X (PTE_V | PTE_X | PTE_U | PTE_A | PTE_D)

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* G-stage: GPA 0x80000000 -> PA 0x80000000 RWX; GPA 0xC0000000 -> PA 0x80000000 execute-only */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 3, 0x80000000, G_X)
  /* VS-stage: VA 0x80000000 -> GPA 0x80000000 */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  HGATP_ON
  /* vsatp root at the execute-only alias of vs_root */
  la a0, vs_root
  li t0, 0x40000000
  add a0, a0, t0
  VSATP_ON(a0)
  la t0, handler
  csrw mtvec, t0
  ENTER_MODE(1, hs)

hs:
  li a2, 0x80000000
  hlvx.hu a1, (a2)
  FAIL(1)            /* no fault: bug */

  .align 2
handler:
  csrr t0, mcause
  li t1, 21
  bne t0, t1, bad
  PASS
bad:
  FAIL(2)

  HYP_TABLES
