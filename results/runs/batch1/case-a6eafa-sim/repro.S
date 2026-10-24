#include "hyp.h"

  .text
  .globl test_main, trap_handler
test_main:
  PMP_ALLOW_ALL
  /* G-stage: GPA gigapage 0 -> PA 0x80000000, execute-only; GPA 0x80000000 identity RWX */
  GIGA_LEAF(g_root, 0, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A | PTE_D))
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  /* VS-stage: VA 0x80000000 -> GPA 0x80000000 */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  HGATP_ON
  la t2, vs_root
  li t3, 0x80000000
  sub t2, t2, t3          /* GPA of VS root, inside the X-only region */
  VSATP_ON(t2)
  la t0, handler
  csrw mtvec, t0
  li t0, HSTATUS_SPVP
  csrs hstatus, t0
  la a1, datum
  hlvx.wu a2, (a1)
  FAIL(1)

  .align 2
trap_handler:
handler:
  csrr t0, mcause
  li t1, 21
  bne t0, t1, 1f
  PASS
1: slli a0, t0, 1; ori a0, a0, 1; j _halt

  .data
  .align 3
datum: .dword 0x1234
  HYP_TABLES
