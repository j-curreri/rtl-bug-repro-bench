/* During an HLVX, the implicit read of a VS-stage page-table entry is an ordinary load for
 * G-stage permission purposes. The VS root sits at a guest-physical alias whose G-stage
 * leaf is execute-only, so the walk must raise a load guest-page fault (cause 21). */
#include "hyp.h"
  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 3, 0x80000000, PTE_V | PTE_X | PTE_U | PTE_A)
  HGATP_ON
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  la t2, vs_root
  li t0, 0x40000000
  add t2, t2, t0               /* guest-physical alias through the execute-only leaf */
  VSATP_ON(t2)
  li t0, HSTATUS_SPVP
  csrs hstatus, t0
  la a1, probe
  hlvx.wu a2, (a1)
  FAIL(2)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 21
  bne t0, t1, 1f
  PASS
1: FAIL(1)

  .data
  .align 4
probe: .word 0x12345678
  HYP_TABLES
