#include "hyp.h"

  .section .text
  .option norvc
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* GPA 0x40000000..0x7fffffff contains the VS page table. */
  GIGA_LEAF(g_root, 1, 0x80000000, G_RWX)

  /* GPA 0x80000000..0xbfffffff is executable, but not readable. */
  GIGA_LEAF(g_root, 2, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A | PTE_D))

  /* VS VA 0x80000000 maps to GPA 0x80000000. */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)

  /* The VS root is itself addressed at GPA 0x40001000. */
  li t0, 0x40001000
  VSATP_ON(t0)
  HGATP_ON
  fence rw, rw
  ENTER_VS(guest_start)

  .align 2
guest_start:
  /* The VS PTE allows this load; G-stage denies it. */
  li t0, 0x80010000
  ld t1, 0(t0)
  FAIL(2)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 21                 /* load guest-page fault */
  bne t0, t1, trap_fail
  PASS
trap_fail:
  FAIL(3)

HYP_TABLES
