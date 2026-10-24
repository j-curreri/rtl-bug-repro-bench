#include "harness/hyp.h"
.text
.globl test_main
.globl trap_handler
test_main:
  PMP_ALLOW_ALL
  # G-stage: GPA 0x40000000 (1GiB idx 1) -> PA 0x80000000, execute-only (+U, A)
  GIGA_LEAF(g_root, 1, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A))
  HGATP_ON
  la t2, dat
  li t3, 0x80000000
  sub t2, t2, t3
  li t3, 0x40000000
  add t2, t2, t3        # guest address of dat
  csrw vsatp, zero
  li t0, HSTATUS_SPVP
  csrs hstatus, t0
  li s1, 0
  hlvx.wu t4, (t2)      # allowed: execute-only readable via HLVX; fills TLB
  hlv.w t5, (t2)        # must raise load guest page fault (no R)
  FAIL(1)
trap_handler:
  csrr t0, mcause
  li t1, 21
  bne t0, t1, bad
  PASS
bad:
  FAIL(2)
.data
.align 3
dat: .dword 0x1234
HYP_TABLES
