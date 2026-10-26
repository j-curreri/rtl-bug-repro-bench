#include "hyp.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  HGATP_ON
  la t0, vs_root
  VSATP_ON(t0)
  ENTER_VS(vs_test)

  .align 2
vs_test:
  /* VS maps this VA, but its G-stage leaf is execute-only. */
  li t0, 0xC0000000
  .globl faulting_load
faulting_load:
  ld t1, 0(t0)
  FAIL(1)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 21                    /* load guest-page fault */
  bne t0, t1, unexpected_cause
  csrr t0, mepc
  la t1, faulting_load
  bne t0, t1, unexpected_pc
  PASS
unexpected_cause:
  FAIL(2)
unexpected_pc:
  FAIL(3)

HYP_TABLES
  /* G-stage: code and page tables are RWX; target GPA is execute-only. */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 3, 0xC0000000, PTE_V | PTE_X | PTE_U | PTE_A | PTE_D)

  /* VS-stage maps both the running code and target address at 1 GiB granularity. */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  GIGA_LEAF(vs_root, 3, 0xC0000000, VS_RWX)
