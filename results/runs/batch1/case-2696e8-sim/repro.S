#include "harness/test.h"
#include "harness/hyp.h"

.globl test_main
.globl trap_handler
test_main:
  PMP_ALLOW_ALL
  /* G-stage: 1GiB page at 0x80000000 is execute-only (user bit set as required) */
  GIGA_LEAF(g_root, 2, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A))
  HGATP_ON
  ENTER_MODE(1, hs_code)

hs_code:
  la t3, datum
  hlvx.wu t2, (t3)
  hlv.w t2, (t3)
  FAIL(2)

trap_handler:
  csrr t0, mcause
  li t1, 21
  bne t0, t1, bad
  PASS
bad:
  FAIL(1)

.balign 8
datum: .word 0x12345678
HYP_TABLES
