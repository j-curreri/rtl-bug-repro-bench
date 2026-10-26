#include "test.h"
#include "hyp.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Map VA 0x80000000 through VS and G stage to DRAM PA 0x80000000. */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  HGATP_ON
  la t0, vs_root
  VSATP_ON(t0)

  /* The M-mode trap handler checks the cause and GVA status bit. */
  ENTER_VS(vs_illegal)

  .align 2
vs_illegal:
  .word 0                   /* Illegal instruction: mtval is not a guest VA. */
1: j 1b

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 2                  /* illegal instruction from VS-mode */
  bne t0, t1, fail_cause

  csrr t0, mstatus
  srli t0, t0, 38
  andi t0, t0, 1            /* GVA */
  bnez t0, fail_gva

  PASS

fail_cause:  FAIL(1)
fail_gva:    FAIL(2)

HYP_TABLES
