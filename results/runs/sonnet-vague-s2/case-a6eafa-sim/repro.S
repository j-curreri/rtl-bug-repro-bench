#include "hyp.h"
.text
.globl test_main
test_main:
  PMP_ALLOW_ALL
  GIGA_LEAF(g_root, 1, 0x80000000, (PTE_V | PTE_R | PTE_U | PTE_A))
  HGATP_ON
  ENTER_MODE(1, s_code)

s_code:
  li s0, 0x40000000
  hlv.w t2, (s0)        # plain load: allowed, caches translation
  hlv.w t2, (s0)
  hlvx.wu t3, (s0)      # needs X in G-stage: must raise load guest page fault
  FAIL(1)

.align 2
.globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 21
  bne t0, t1, bad
  PASS
bad:
  FAIL(2)

HYP_TABLES
