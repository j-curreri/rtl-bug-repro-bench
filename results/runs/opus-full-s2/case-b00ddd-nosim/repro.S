#include "hyp.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* G-stage: identity map GPA 0x80000000 (1 GiB) */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  HGATP_ON
  csrw vsatp, zero
  /* clear GVA before entering the guest */
  li t0, MSTATUS_GVA
  csrc mstatus, t0
  ENTER_VS(guest)

  .align 2
guest:
  /* OP-V instruction (vadd.vv v0,v0,v0): illegal, no V extension, not a copro opcode */
  .word 0x00000057
  /* should never get here */
  ecall

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 2
  bne t0, t1, bad_cause
  csrr t0, mstatus
  li t1, MSTATUS_MPV
  and t2, t0, t1
  beqz t2, not_virt
  li t1, MSTATUS_GVA
  and t2, t0, t1
  bnez t2, gva_set
  PASS
bad_cause:
  FAIL(1)
not_virt:
  FAIL(2)
gva_set:
  FAIL(3)

  HYP_TABLES
