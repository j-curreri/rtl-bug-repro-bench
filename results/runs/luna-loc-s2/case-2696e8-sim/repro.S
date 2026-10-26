#include "hyp.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Install one 1 GiB G-stage mapping covering gdata.  The page is
     executable and user accessible, but deliberately not readable. */
  la t0, g_root
  la t1, gdata
  srli t2, t1, 30
  andi t2, t2, 511
  slli t2, t2, 3
  add t0, t0, t2
  li t2, -1
  slli t2, t2, 30
  and t1, t1, t2            /* align physical base for the 1 GiB leaf */
  srli t1, t1, 12
  slli t1, t1, 10
  ori t1, t1, (PTE_V | PTE_X | PTE_U | PTE_A | PTE_D)
  sd t1, 0(t0)

  HGATP_ON
  la s1, gdata
  ENTER_MODE(1, hs_test)

  .align 2
hs_test:
  /* HLVX may read an execute-only G-stage page.  This fills the DTLB. */
  hlvx.hu a0, (s1)
  /* A normal load to the cached mapping must fault: G-stage R is clear. */
plain_hlv:
  hlv.hu a1, (s1)
  la t0, fault_seen
  ld t0, 0(t0)
  beqz t0, fail_unexpected_success
  PASS

fail_unexpected_success:
  FAIL(1)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 21                 /* load guest-page fault */
  bne t0, t1, fail_trap
  csrr t0, mepc
  la t1, plain_hlv
  bne t0, t1, fail_trap     /* HLVX must succeed first */
  la t0, fault_seen
  li t1, 1
  sd t1, 0(t0)
  addi t0, t0, 4            /* skip the HLV.HU that faulted */
  csrw mepc, t0
  mret

fail_trap:
  FAIL(2)

  HYP_TABLES
  .align 3
fault_seen:
  .dword 0
  .align 12
gdata:
  .word 0x12345678
