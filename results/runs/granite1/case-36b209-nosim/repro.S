#include "hyp.h"
#include "test.h"

.section .data
HYP_TABLES
GIGA_LEAF(g_root, 0, 0x80000000, G_RWX)
GIGA_LEAF(vs_root, 0, 0x80000000, G_RWX)

// vs_root[1] = non-leaf PTE pointing to level-2 table 0 (guest-physical 0x00000000, outside guest-physical range)
RAW_PTE(vs_root, 1, PTE_V)

test_vs:
  li a0, 0x01000000  // guest-virtual page 1 maps to vs_root[1]

.globl test_main
test_main:
  li t0, 0
  PMP_ALLOW_ALL

  HGATP_ON

  la t2, vs_root
  li t3, 0x80000000
  VSATP_ON(t3)

  ENTER_VS(test_vs)

  lb t0, 0(x1)

  PASS

.weak trap_handler
trap_handler:
  csrr t6, mcause
  li t0, 0
  csrr t0, mcause
  beq t0, x0, always_fail  // no fault -> bug
  li t0, 1  // PASS
  j _halt

always_fail:
  li t0, 1  // FAIL(1)
  j _halt
