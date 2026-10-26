#include "hyp.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  GIGA_LEAF(vs_root, 0, 0x80000000, VS_RWX)

  /* G-stage root[2] points to a level-1 table. */
  la t0, g_root
  li t1, 2
  slli t1, t1, 3
  add t0, t0, t1
  la t2, g_l1
  srli t2, t2, 12
  slli t2, t2, 10
  ori t2, t2, PTE_V
  sd t2, 0(t0)

  /* Map the first 2 MiB with 4 KiB leaves so the VS page tables and guest
     code are reachable through G-stage. */
  la t0, g_l0
  li t1, 0
1:
  slli t2, t1, 12
  li t3, 0x80000000
  add t2, t2, t3
  srli t2, t2, 12
  slli t2, t2, 10
  ori t2, t2, G_RWX
  sd t2, 0(t0)
  addi t0, t0, 8
  addi t1, t1, 1
  li t3, 512
  bltu t1, t3, 1b

  /* Map the remaining 2 MiB chunks with identity-mapped G-stage leaves. */
  la t0, g_l1
  la t1, g_l0
  srli t1, t1, 12
  slli t1, t1, 10
  ori t1, t1, PTE_V
  sd t1, 0(t0)
  li t2, 1
2:
  /* 2 MiB leaf for GPA 0x80000000 + idx*2 MiB. */
  slli t3, t2, 21
  li t4, 0x80000000
  add t3, t3, t4
  srli t3, t3, 12
  slli t3, t3, 10
  ori t3, t3, G_RWX
  slli t4, t2, 3
  add t4, t4, t0
  sd t3, 0(t4)
  addi t2, t2, 1
  li t3, 512
  bltu t2, t3, 2b

  HGATP_ON
  la t0, vs_root
  VSATP_ON(t0)
  ENTER_VS(guest_entry)

  .align 2
  .globl guest_entry
guest_entry:
  /* The VS-stage leaf permits supervisor access, but the G-stage leaf for
     this GPA has U=1. With SUM clear, VS-S must receive a guest-page fault. */
  li t0, 0x10000000       /* VS leaf maps this to GPA 0x90000000 */
  ld t1, 0(t0)
  /* Reaching here means the required fault was missed. */
  FAIL(1)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 21                  /* load guest-page fault */
  beq t0, t1, trap_pass
  FAIL(2)
trap_pass:
  PASS

  HYP_TABLES
  .align 12
g_l1: .space 4096
  .align 12
g_l0: .space 4096
