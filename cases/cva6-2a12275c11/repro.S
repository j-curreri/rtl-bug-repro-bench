/* An illegal instruction in VS-mode must trap with mstatus.GVA = 0 (mtval holds no guest
 * virtual address for illegal-instruction exceptions). */
#include "hyp.h"
  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  HGATP_ON
  csrw vsatp, zero
  ENTER_VS(in_vs)
in_vs:
  .word 0x0000000b             /* custom-0: not implemented by the coprocessor */
  ecall

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 2
  bne t0, t1, 1f
  csrr t0, mstatus
  li t1, MSTATUS_GVA
  and t0, t0, t1
  bnez t0, 2f
  PASS
1: FAIL(1)
2: FAIL(2)

  HYP_TABLES
