#include "test.h"
#include "hyp.h"
.text
.globl test_main
.globl trap_handler
test_main:
  PMP_ALLOW_ALL
  /* G-stage: 1GiB leaf at 0x80000000, R/W/U/A/D but not X */
  GIGA_LEAF(g_root, 2, 0x80000000, (PTE_V|PTE_R|PTE_W|PTE_U|PTE_A|PTE_D))
  HGATP_ON
  la s1, data
  la s2, traps
  ENTER_MODE(1, hs_code)
hs_code:
  hlv.w t2, (s1)      /* allowed: fills DTLB */
  ld t3, 0(s2)
  bnez t3, fail1
  hlvx.wu t2, (s1)    /* must fault: no X in G-stage */
  ld t3, 0(s2)
  li t4, 1
  bne t3, t4, fail2
  PASS
fail1: FAIL(1)
fail2: FAIL(2)
trap_handler:
  csrr t5, mcause
  li t6, 21
  bne t5, t6, bad
  la t5, traps
  ld t6, 0(t5)
  addi t6, t6, 1
  sd t6, 0(t5)
  csrr t5, mepc
  addi t5, t5, 4
  csrw mepc, t5
  mret
bad:
  FAIL(3)
.data
.align 3
traps: .dword 0
data: .dword 0x1234
HYP_TABLES
