#include "hyp.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Identity-map the DRAM's 1 GiB region through both stages.  A
   * supervisor guest may execute and read a supervisor G-stage page, whose
   * U bit is clear. */
  GIGA_LEAF(g_root, 2, 0x80000000, (PTE_V | PTE_R | PTE_W | PTE_X | PTE_A | PTE_D))
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)

  HGATP_ON
  la t0, vs_root
  VSATP_ON(t0)

  ENTER_VS(guest_start)

  .align 2
guest_start:
  la t0, guest_data
  ld t1, 0(t0)
  li t2, 0x13579bdf2468ace0
  bne t1, t2, guest_fail
  li a0, 1
  j _halt
guest_fail:
  FAIL(1)

  .align 3
guest_data:
  .dword 0x13579bdf2468ace0

  .globl trap_handler
trap_handler:
  FAIL(127)

  HYP_TABLES
