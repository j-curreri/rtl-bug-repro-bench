#include "harness/hyp.h"
.text
.globl test_main
test_main:
  PMP_ALLOW_ALL
  la t2, trap_handler
  csrw mtvec, t2
  /* G-stage: 1GiB page at 0x80000000, execute-only (no R) */
  GIGA_LEAF(g_root, 2, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A))
  HGATP_ON
  csrw vsatp, zero
  la a1, g_root
  hlvx.wu a2, (a1)      /* legal: X page; fills DTLB */
  hlv.w a3, (a1)        /* must raise load guest page fault */
  FAIL(1)

.balign 4
.globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 21
  bne t0, t1, 1f
  PASS
1:
  FAIL(2)

HYP_TABLES
