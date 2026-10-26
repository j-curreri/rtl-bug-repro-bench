#include "test.h"
#include "hyp.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  # G-stage gigapage for GPA 0x80000000 -> PA 0x80000000: execute-only (no R, no W), user page
  GIGA_LEAF(g_root, 2, 0x80000000, PTE_V | PTE_X | PTE_U | PTE_A | PTE_D)
  HGATP_ON
  la t2, dat

  # HLVX.HU reads through an execute-only G-stage page: allowed. Fills the DTLB.
  hlvx.hu t3, 0(t2)

  # Plain HLV.D to the same page has no read permission at G-stage: must raise
  # load guest page fault (cause 21). The buggy core hits the DTLB and succeeds.
hlv_insn:
  hlv.d t3, 0(t2)
  FAIL(1)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 21
  bne t0, t1, 1f
  # the trap must come from the HLV.D itself, not from the HLVX
  csrr t0, mepc
  la t1, hlv_insn
  bne t0, t1, 1f
  PASS
1:
  FAIL(2)

HYP_TABLES

  .data
  .align 3
dat: .dword 0x1122334455667788
