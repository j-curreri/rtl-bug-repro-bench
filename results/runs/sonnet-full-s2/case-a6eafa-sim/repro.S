#include "harness/hyp.h"
.text
.globl test_main
test_main:
  PMP_ALLOW_ALL
  la t0, trap_handler
  csrw mtvec, t0
  # G-stage: GPA 0x40000000 -> HPA 0x80000000 execute-only (holds VS tables); GPA 0x80000000 identity RWX
  GIGA_LEAF(g_root, 1, 0x80000000, (PTE_V|PTE_X|PTE_U|PTE_A|PTE_D))
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  # VS-stage: VA 0 -> GPA 0x80000000 (X, readable only via HLVX)
  GIGA_LEAF(vs_root, 0, 0x80000000, VS_RWX)
  HGATP_ON
  la t2, vs_root
  li t3, 0x40000000
  sub t2, t2, t3
  VSATP_ON(t2)
  li t0, HSTATUS_SPVP
  csrs hstatus, t0
  ENTER_MODE(1, hs)
hs:
  li a1, 0
  hlvx.hu a2, (a1)
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
HYP_TABLES
