#include "hyp.h"
.text
.globl test_main
test_main:
  la t0, trap_handler
  csrw mtvec, t0
  PMP_ALLOW_ALL
  /* G-stage 1GiB leaf for GPA 0x80000000: V R W U A D, no X */
  GIGA_LEAF(g_root, 2, 0x80000000, (PTE_V|PTE_R|PTE_W|PTE_U|PTE_A|PTE_D))
  HGATP_ON
  li s1, 0
  la a1, data
  hlv.d t2, (a1)        /* plain load: fills DTLB */
  bnez s1, fail1
  hlvx.hu t3, (a1)      /* needs X: must raise load guest page fault */
  li t0, 1
  bne s1, t0, fail2
  PASS
fail1: FAIL(1)
fail2: FAIL(2)

.balign 4
.globl trap_handler
trap_handler:
  csrr t5, mcause
  li t6, 21
  bne t5, t6, bad
  addi s1, s1, 1
  csrr t5, mepc
  addi t5, t5, 4
  csrw mepc, t5
  mret
bad: FAIL(3)

HYP_TABLES
.data
.align 3
data: .dword 0x1234
