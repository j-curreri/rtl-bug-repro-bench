#include "harness/hyp.h"
.text
.globl test_main
test_main:
  PMP_ALLOW_ALL
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 0, 0x80000000, (PTE_V|PTE_X|PTE_U|PTE_A))
  HGATP_ON
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  la t2, vs_root
  li t3, 0x80000000
  sub t2, t2, t3        # gpa of vs_root via X-only alias
  VSATP_ON(t2)
  li t0, (1<<19)        # mstatus.MXR
  csrs mstatus, t0
  ENTER_VS(vs_code)
vs_code:
  PASS
.data
HYP_TABLES
.text
.globl trap_handler
.align 2
trap_handler:
  csrr a0, mcause
  slli a0, a0, 1
  ori a0, a0, 1
  j _halt
