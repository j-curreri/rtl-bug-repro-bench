#include "hyp.h"
  .option norvc
  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  la t0, trap_handler
  csrw mtvec, t0
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 8, 0x80000000, G_RWX)
  la s0, l1v
  srli s0, s0, 2
  la t1, vs_root
  ori t2, s0, 0x1
  sd t2, 72(t1)           # idx9 nonleaf plain
  ori t2, s0, 0x41
  sd t2, 80(t1)           # idx10 nonleaf A
  ori t2, s0, 0x11
  sd t2, 88(t1)           # idx11 nonleaf U
  ori t2, s0, 0x81
  sd t2, 96(t1)           # idx12 nonleaf D
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  GIGA_LEAF(vs_root, 0, 0x80000000, PTE_V|PTE_R|PTE_A)            # no D
  GIGA_LEAF(vs_root, 1, 0x80000000, PTE_V|PTE_R)                  # A=0
  GIGA_LEAF(vs_root, 3, 0x80000000, PTE_V|PTE_R|PTE_A|PTE_U)      # U
  GIGA_LEAF(vs_root, 4, 0x80000000, PTE_V|PTE_X|PTE_A)            # X only
  RAW_PTE(vs_root, 5, ((0x80000000 >> 12 << 10) | PTE_V|PTE_R|PTE_A|(1<<54)))
  RAW_PTE(vs_root, 6, ((0x80001000 >> 12 << 10) | PTE_V|PTE_R|PTE_A))
  GIGA_LEAF(vs_root, 7, 0x80000000, PTE_V|PTE_W|PTE_A|PTE_D)      # W no R
  GIGA_LEAF(vs_root, 8, 0x80000000, PTE_V|PTE_R|PTE_A)            # plain
  RAW_PTE(vs_root, 13, ((0x80000000 >> 12 << 10) | PTE_V|PTE_R|PTE_A|(1<<30)))  # ppn bit above 41
  GIGA_LEAF(vs_root, 14, 0x300000000, PTE_V|PTE_R|PTE_A)            # GPA unmapped in G
  HGATP_ON
  GIGA_LEAF(g_root, 3, 0x80000000, PTE_V|PTE_R|PTE_W|PTE_U|PTE_A|PTE_D)
  la t2, vs_root
  li t0, 0x40000000
  add t2, t2, t0
  VSATP_ON(t2)
  li t0, HSTATUS_SPVP
  csrs hstatus, t0
  li s11, 0
  li t2, (4 << 30)
  hlvx.hu t3, (t2)
  bnez s11, hf1
  PASS
hf1: FAIL(41)

  .align 2
trap_handler:
  csrr s11, mcause
  csrr t6, mepc
  addi t6, t6, 4
  csrw mepc, t6
  mret
old_handler:
  csrr s11, mcause
  csrr t6, mepc
  addi t6, t6, 4
  csrw mepc, t6
  mret

#define LOADT(n, idx, expect) \
  li s11, 0; li t2, ((idx) << 30); ld t3, 0(t2); \
  li t4, expect; bne s11, t4, fail##n;
#define STORET(n, idx, expect) \
  li s11, 0; li t2, ((idx) << 30); sd zero, 0(t2); \
  li t4, expect; bne s11, t4, fail##n;

vsmode:
  LOADT(1, 8, 0)
  LOADT(2, 0, 0)
  STORET(3, 0, 15)
  LOADT(4, 1, 13)
  LOADT(5, 3, 13)
  LOADT(6, 4, 13)
  LOADT(7, 5, 13)
  LOADT(8, 6, 13)
  LOADT(9, 7, 13)
  LOADT(10, 9, 0)
  LOADT(11, 10, 13)
  LOADT(12, 11, 13)
  LOADT(13, 12, 13)
  LOADT(14, 13, 21)
  LOADT(15, 14, 21)
  PASS
#define F(n) fail##n: FAIL(n);
F(1)
F(2)
F(3)
F(4)
F(5)
F(6)
F(7)
F(8)
F(9)
F(10)
F(11)
F(12)
F(13)
F(14)
F(15)
  .data
  .balign 4096
l1v:
  .dword ((0x80000000>>2) | 0x4b)
  .fill 511, 8, 0
HYP_TABLES
