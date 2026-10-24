#include "hyp.h"

/* VS-stage non-leaf PTE whose PPN points to GPA 2^41, outside the Sv39x4
 * guest-physical space (GPLEN = 41). A VS-mode load through it must raise a
 * load guest-page fault (cause 21), not a load page fault (cause 13). */

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* G-stage: identity map GPA 0x80000000 (1 GiB) */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  /* VS-stage: identity map VA 0x80000000 (code/data) */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  /* VS-stage: vs_root[1] is a non-leaf PTE with PPN = 1<<29 (GPA 1<<41) */
  RAW_PTE(vs_root, 1, ((1 << 29) << 10) | PTE_V)
  fence
  HGATP_ON
  la t2, vs_root
  VSATP_ON(t2)
  ENTER_VS(vs_code)

vs_code:
  li t3, 0x40000000
  ld t4, 0(t3)
  /* load should have trapped */
  j vs_code_fail
vs_code_fail:
  ecall

  .align 2
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  li t5, 21
  beq t6, t5, 1f
  li t5, 13
  beq t6, t5, 2f
  FAIL(3)
2:
  FAIL(2)
1:
  csrr t5, mtval
  li t4, 0x40000000
  bne t5, t4, 3f
  PASS
3:
  FAIL(4)

  HYP_TABLES
