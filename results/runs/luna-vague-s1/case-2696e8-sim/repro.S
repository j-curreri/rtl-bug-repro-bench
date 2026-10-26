#include "test.h"
#include "hyp.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Map the DRAM 1 GiB region with execute permission only. HLVX may read
     through X, while an ordinary HLV load must fault. */
  GIGA_LEAF(g_root, 2, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A))
  HGATP_ON

  /* HLV instructions use SPVP to choose the guest access privilege. */
  li t0, HSTATUS_SPVP
  csrs hstatus, t0
  ENTER_MODE(1, hs_test)

hs_test:
  la t0, test_data
  hlvx.wu t1, (t0)
  /* The successful HLVX above has cached the execute-only G-stage leaf. */
  hlv.wu t2, (t0)
  /* Reaching here means the cached leaf incorrectly allowed a plain read. */
  FAIL(1)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 21                 /* load guest-page fault */
  beq t0, t1, expected_fault
  FAIL(2)
expected_fault:
  PASS

  .section .data
  .align 2
test_data:
  .word 0x12345678

  HYP_TABLES
