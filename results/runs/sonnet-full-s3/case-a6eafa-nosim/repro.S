#include "hyp.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* G-stage: GPA gigapage 2 identity RWX (code/data); gigapage 1 -> PA 0x80000000, execute-only */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 1, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A | PTE_D))
  HGATP_ON
  /* VS-stage: VA gigapage 2 -> GPA 0x80000000 */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  /* VS root's guest-physical address lies in the execute-only window */
  la a2, vs_root
  li t1, 0x3fffffff
  and a2, a2, t1
  li t1, 0x40000000
  add a2, a2, t1
  VSATP_ON(a2)
  li t0, HSTATUS_SPVP
  csrs hstatus, t0
  la t0, vs_root
  ENTER_MODE(1, hs_code)

hs_code:
  la a3, probe
  hlvx.hu a1, 0(a3)
  FAIL(1)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 21
  bne t0, t1, bad
  PASS
bad:
  FAIL(2)

probe: .word 0x00000013

  HYP_TABLES
