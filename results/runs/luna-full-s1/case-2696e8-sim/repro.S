#include "test.h"
#include "hyp.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  # G-stage: map the first 2 MiB of DRAM RWX, where the page tables live.
  # Split the next 2 MiB so 0x80400000 is an execute-only 4 KiB page.
  la t0, g_l1
  srli t0, t0, 12
  slli t0, t0, 10
  ori t0, t0, PTE_V
  la t1, g_root
  sd t0, 16(t1)                 # g_root[2] -> g_l1

  li t0, 0x200000df             # 0x80000000, 2 MiB RWXUAD leaf
  la t1, g_l1
  sd t0, 0(t1)                  # g_l1[0]

  la t0, g_target_pt
  srli t0, t0, 12
  slli t0, t0, 10
  ori t0, t0, PTE_V
  la t1, g_l1
  sd t0, 16(t1)                 # g_l1[2] -> target 4 KiB table
  li t0, 0x20100059             # 0x80400000, V|X|U|A only
  la t1, g_target_pt
  sd t0, 0(t1)

  # VS-stage: VA 0x40000000 -> GPA 0x80400000 (2 MiB leaf).
  la t0, vs_l1
  srli t0, t0, 12
  slli t0, t0, 10
  ori t0, t0, PTE_V
  la t1, vs_root
  sd t0, 8(t1)                  # vs_root[1] -> vs_l1
  li t0, 0x2010005b             # 0x80400000, V|R|X|U|A
  la t1, vs_l1
  sd t0, 0(t1)

  # Enable G-stage translation, then install the VS root for HLVX.HU.
  la t0, g_root
  srli t0, t0, 12
  li t1, SATP_SV39               # HGATP Sv39x4 mode
  or t0, t0, t1
  csrw hgatp, t0
  hfence.gvma

  la t0, vs_root
  srli t0, t0, 12
  li t1, SATP_SV39
  or t0, t0, t1
  csrw vsatp, t0
  hfence.vvma

  # Run the two accesses in HS-mode, with the same underlying guest page.
  ENTER_MODE(1, hs_test)

hs_test:
  li a0, 0x40000000
  hlvx.hu a1, (a0)               # allowed: G-stage X permission acts as R
  li a0, 0x40000000
  hlv.w a2, (a0)                 # must guest-page-fault: G-stage page is X-only
  FAIL(1)                        # the buggy core incorrectly reaches here

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 21                      # load guest-page fault
  beq t0, t1, expected_fault
  FAIL(127)
expected_fault:
  PASS

  HYP_TABLES
  .align 12
g_l1: .space 4096
  .align 12
g_target_pt: .space 4096
  .align 12
vs_l1: .space 4096
