#include "hyp.h"
  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 3, 0x80000000, (PTE_V|PTE_X|PTE_U|PTE_A))
  HGATP_ON
  li t0, 0x80000
  csrs mstatus, t0
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  la t2, vs_root
  li t0, 0x7fffffff
  and t2, t2, t0
  li t0, 0xC0000000
  or t2, t2, t0
  VSATP_ON(t2)
  ENTER_VS(guest)
  .align 4
guest:
  la t2, data
  ld t6, 0(t2)
  ecall
  .align 4
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 10
  bne t0, t1, f
  PASS
f:
  FAIL(5)
  .data
data: .dword 0
HYP_TABLES
