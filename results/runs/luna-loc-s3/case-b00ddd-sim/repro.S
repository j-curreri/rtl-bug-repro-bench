#include "hyp.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Identity map the 0x80000000 GiB region for guest physical and virtual
     addresses.  The code and stack are both in this region. */
  GIGA_LEAF(g_root, 2, 0x80000000, (PTE_V | PTE_R | PTE_W | PTE_X | PTE_A | PTE_D))
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  HGATP_ON
  la t0, vs_root
  VSATP_ON(t0)

  ENTER_MODE(1, hs_entry)

hs_entry:
  /* Enter VS through the architectural HS SRET path. */
  li t0, (1 << 7)
  csrs hstatus, t0
  li t0, (1 << 8)
  csrs sstatus, t0
  la t0, vs_test
  csrw sepc, t0
  sret

  .align 2
vs_test:
  /* Unsupported custom instruction: CVXIF rejects the offload. */
  .word 0x0200000b
1: j 1b

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mstatus
  srli t0, t0, 38
  andi t0, t0, 1
  bnez t0, bad_gva
  PASS
bad_gva:
  FAIL(1)

  HYP_TABLES
