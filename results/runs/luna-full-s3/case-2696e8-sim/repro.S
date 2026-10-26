#include "hyp.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* GPA 0x80000000 maps to the same HPA, but is execute-only for guests. */
  GIGA_LEAF(g_root, 2, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A))
  HGATP_ON

  /* HLV/HLVX perform the guest access using the privilege in SPVP. */
  li t0, (1 << 19)           /* Keep MXR and VMXR clear. */
  csrc mstatus, t0
  csrc hstatus, t0
  li t0, HSTATUS_SPVP
  csrs hstatus, t0
  ENTER_MODE(1, hs_test)

hs_test:
  li a0, 0x80000000
  hlvx.hu t1, (a0)
  /* This plain load must fault even though the preceding HLVX succeeded. */
  .globl do_hlv
do_hlv:
  hlv.hu t2, (a0)
  FAIL(1)

  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 21                  /* Load guest-page fault. */
  bne t0, t1, unexpected_trap
  csrr t0, mepc
  la t1, do_hlv
  bne t0, t1, unexpected_trap
  PASS

unexpected_trap:
  FAIL(2)

  HYP_TABLES
