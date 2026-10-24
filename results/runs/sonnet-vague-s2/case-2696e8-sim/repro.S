#include "harness/test.h"
#include "harness/hyp.h"
.text
.globl test_main
.globl trap_handler
test_main:
  PMP_ALLOW_ALL
  # G-stage: GPA 0x80000000 (idx 2) identity, execute-only (no R/W)
  GIGA_LEAF(g_root, 2, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A))
  HGATP_ON
  la t0, trap_handler
  csrw mtvec, t0
  ENTER_MODE(1, smode)
smode:
  la a0, probe
  hlvx.wu t2, (a0)     # allowed on exec-only page, fills DTLB
  hlv.w t3, (a0)       # must raise load guest page fault
  FAIL(5)
trap_handler:
  csrr t0, mcause
  li t1, 21
  bne t0, t1, 1f
  PASS
1:
  FAIL(2)
.data
.align 3
probe: .word 0x12345678
HYP_TABLES
