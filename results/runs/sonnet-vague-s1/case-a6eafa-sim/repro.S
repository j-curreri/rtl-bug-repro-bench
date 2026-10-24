#include "harness/hyp.h"
.option norvc
.text
.globl test_main
.globl trap_handler
.align 2
trap_handler:
  csrr a3, mcause
  li t5, 10
  beq a3, t5, 2f
  csrr t5, mepc
  addi t5, t5, 4
  csrw mepc, t5
  mret
2:
  bnez a5, 3f
  PASS
3:
  slli a0, a5, 1
  ori a0, a0, 1
  j _halt

test_main:
  PMP_ALLOW_ALL
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  # GPA 0x100000000.. aliases RAM but with G-stage U=0
  GIGA_LEAF(g_root, 4, 0x80000000, (G_RWX & ~PTE_U))
  # VS root: [2] = code/data gigapage, [3] = pointer to vs_l1 (reached via U=0 alias)
  la t0, vs_root
  li t1, VS_RWX
  li t2, (0x80000000 >> 12 << 10)
  or t1, t1, t2
  sd t1, 16(t0)
  la t3, vs_l1
  li t1, 0x3fffffff
  and t3, t3, t1
  li t1, 4<<30
  or t3, t3, t1
  srli t3, t3, 12
  slli t3, t3, 10
  ori t3, t3, PTE_V
  sd t3, 24(t0)
  la t0, vs_l1
  li t1, VS_RWX
  li t2, (0x80000000 >> 12 << 10)
  or t1, t1, t2
  sd t1, 0(t0)
  HGATP_ON
  la t0, vs_root
  VSATP_ON(t0)
  ENTER_VS(vs_code)

.align 4
vs_code:
  li a5, 1
  li a3, 0
  li t2, 3<<30
  ld t3, 0(t2)     # VS page-table walk reads l1 through a G-stage U=0 page: guest page fault
  li t4, 21
  bne a3, t4, bad
  li a5, 0
bad:
  ecall
.data
.align 12
vs_l1: .space 4096
HYP_TABLES
