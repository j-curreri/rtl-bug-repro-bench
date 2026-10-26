#include "hyp.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  /* Allow lower privilege modes to access DRAM. */
  PMP_ALLOW_ALL

  /* Identity map the 0x80000000 DRAM region at both translation stages. */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)

  HGATP_ON
  la t0, vs_root
  VSATP_ON(t0)

  /* An illegal instruction in VS-mode must trap to the M-mode handler. */
  ENTER_VS(vs_illegal)

  .align 2
vs_illegal:
  .option push
  .option norvc
  /* Custom-3 opcode with an unimplemented funct7: sent through CV-X-IF,
   * then rejected as an illegal instruction. */
  .word 0x0200007b
  .option pop
  /* Reaching this point means the reserved encoding was not trapped. */
  FAIL(1)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 2
  bne t0, t1, trap_unexpected

  /* GVA must be clear for an illegal-instruction exception. */
  csrr t0, mstatus
  li t1, MSTATUS_GVA
  and t0, t0, t1
  bnez t0, trap_bad_gva
  PASS

trap_bad_gva:
  FAIL(2)
trap_unexpected:
  FAIL(3)

  HYP_TABLES
