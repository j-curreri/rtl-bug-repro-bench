/* Reproducer: HLVX must check execute permission at the G-stage, also on a TLB hit.
 * The G-stage maps the DRAM gigapage readable but not executable. A plain HLV.D
 * fills the TLB and must succeed. A following HLVX.WU hits that TLB entry and must
 * raise a load guest-page fault (cause 21) because HLVX requires X. */
#include "hyp.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* G-stage identity map of the 1 GiB DRAM gigapage: readable, user, no execute. */
  GIGA_LEAF(g_root, 2, 0x80000000, PTE_V | PTE_R | PTE_U | PTE_A | PTE_D)
  HGATP_ON

  la s0, dat

  /* Case 1: plain HLV.D fills the TLB. Must succeed without a trap. */
  la t0, g_traps
  sd zero, 0(t0)
  hlv.d a1, (s0)
  la t0, g_traps
  ld t1, 0(t0)
  bnez t1, bad1

  /* Case 2: HLVX.WU hits the TLB entry. Must trap. */
  hlvx.wu a1, (s0)
  la t0, g_traps
  ld t1, 0(t0)
  li t2, 1
  bne t1, t2, bad2

  PASS

bad1: FAIL(1)
bad2: FAIL(2)

  /* Expected trap: load guest-page fault (cause 21). Skip the faulting instruction. */
  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 21
  bne t0, t1, 2f
  la t0, g_traps
  ld t1, 0(t0)
  addi t1, t1, 1
  sd t1, 0(t0)
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret
2:
  FAIL(100)

  .data
  .align 3
g_traps: .dword 0
dat:     .dword 0

HYP_TABLES
