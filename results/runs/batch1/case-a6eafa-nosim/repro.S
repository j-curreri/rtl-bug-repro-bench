#include "harness/hyp.h"
.text
.globl test_main
.globl trap_handler
test_main:
  PMP_ALLOW_ALL
  /* G-stage: 1 GiB at 0x80000000 identity-mapped, execute-only */
  GIGA_LEAF(g_root, 2, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A | PTE_D))
  /* VS-stage: identity 1 GiB RWX leaf */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  HGATP_ON
  la t2, vs_root
  VSATP_ON(t2)
  li t0, HSTATUS_SPVP
  csrs hstatus, t0
  la t3, target
  hlvx.hu t4, (t3)
  FAIL(1)
trap_handler:
  csrr t0, mcause
  li t1, 21
  bne t0, t1, bad
  PASS
bad:
  FAIL(2)
target: .word 0x13
HYP_TABLES
