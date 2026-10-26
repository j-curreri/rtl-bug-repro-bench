/* Probe: mixed page sizes across VS-stage and G-stage, guest loads from HS-mode. */
#include "hyp.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  /* G: root idx 1 (GPA 0x40000000) -> l1_tab; l1_tab[0] = 2 MiB leaf GPA 0x40000000 -> PA 0x80000000 */
  la t2, l1_tab
  srli t2, t2, 12
  slli t2, t2, 10
  ori t2, t2, PTE_V
  la t0, g_root
  sd t2, 8(t0)
  RAW_PTE(l1_tab, 0, ((0x80000000 >> 12) << 10) | G_RWX)
  HGATP_ON
  /* VS: GVA 0x40000000 -> 2 MiB leaf at vs l1 index 0 -> GPA 0x80000000 */
  la t2, vs_l1
  srli t2, t2, 12
  slli t2, t2, 10
  ori t2, t2, PTE_V
  la t0, vs_root
  sd t2, 8(t0)
  RAW_PTE(vs_l1, 0, ((0x80000000 >> 12) << 10) | VS_RWX)
  /* VS: GVA 0x80000000 -> 1 GiB leaf GPA 0x80000000 */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  la t2, vs_root
  VSATP_ON(t2)
  ENTER_MODE(1, hs_entry)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t6, mcause
  la t0, cur_case
  ld t1, 0(t0)
  slli a0, t1, 6
  or a0, a0, t6
  slli a0, a0, 1
  ori a0, a0, 1
  j _halt

hs_entry:
  li t0, HSTATUS_SPVP
  csrs hstatus, t0
  la a1, cur_case
  li t1, 0
  sd t1, 0(a1)
  li a2, 0x40000000
  hlv.w a0, (a2)
  la a1, cur_case
  li t1, 1
  sd t1, 0(a1)
  li a2, 0x40001000
  hlv.w a0, (a2)
  la a1, cur_case
  li t1, 2
  sd t1, 0(a1)
  li a2, 0x80000000
  hlv.w a0, (a2)
  PASS

  HYP_TABLES
  .align 12
  l1_tab: .space 4096
  vs_l1: .space 4096

  .data
  .align 3
  cur_case: .dword 0
