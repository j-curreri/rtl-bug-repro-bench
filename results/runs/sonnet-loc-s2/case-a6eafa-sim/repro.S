#include "hyp.h"
  .option norvc
  .text
  .globl test_main
  .globl trap_handler
  .align 2
trap_handler:
  csrr s2, mcause
  csrr s3, 0x34b
  csrr t6, mepc
  addi t6, t6, 4
  csrw mepc, t6
  mret

#define L(ppn, fl) .dword ((ppn) << 10) | (fl)

#define HV(va, cause, val, n) \
  li s2, 0; li t1, 0; li t0, va; hlv.d t1, (t0); \
  li t2, cause; bne s2, t2, 7f; li t2, val; bne t1, t2, 7f; \
  j 8f; 7: mv a0, s3; slli a0, a0, 8; ori a0, a0, n; slli a0, a0, 1; ori a0, a0, 1; j _halt; 8:

test_main:
  PMP_ALLOW_ALL
  li t0, 0xD0; li t1, 0x80400008; sd t0, 0(t1)
  li t0, 0xD2; li t1, 0x804FF008; sd t0, 0(t1)
  li t0, 0xD3; li t1, 0x80580008; sd t0, 0(t1)
  li t0, 0xD4; li t1, 0x8047F008; sd t0, 0(t1)
  li t0, 0xD5; li t1, 0x80500008; sd t0, 0(t1)
  # gl0f: entry j -> PA 0x80400000 + j*4K
  la t4, gl0f; li t5, 0x80400; li t6, 512
1: slli t0, t5, 10; ori t0, t0, 0xDF; sd t0, 0(t4); addi t4, t4, 8; addi t5, t5, 1; addi t6, t6, -1; bnez t6, 1b
  la t3, g_root; la t0, gl1f; srli t0, t0, 2; ori t0, t0, 1; sd t0, 31*8(t3)
  la t3, gl1f; la t0, gl0f; srli t0, t0, 2; ori t0, t0, 1; sd t0, 0(t3)
  la t3, vs_root; la t0, vl1g; srli t0, t0, 2; ori t0, t0, 1; sd t0, 26*8(t3)
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  GIGA_LEAF(vs_root, 27, 0x7C0000000, VS_RWX)   # gpa 31<<30
  HGATP_ON
  li t0, HSTATUS_SPVP
  csrs 0x600, t0
  la t2, vs_root
  VSATP_ON(t2)
  # VS mega leaf (vl1g[0]) -> GPA 31<<30 ; G 4K
  HV((26<<30)+0x8, 0, 0xD0, 4)
  # VS giga leaf -> GPA 31<<30 ; G 4K (offset bits 20:12 only meaningful)
  PASS

  HYP_TABLES
  .align 12
gl1f:
  .fill 512, 8, 0
gl0f:
  .fill 512, 8, 0
vl1g:
  L(0x7C000, 0xCF)
  .fill 511, 8, 0
