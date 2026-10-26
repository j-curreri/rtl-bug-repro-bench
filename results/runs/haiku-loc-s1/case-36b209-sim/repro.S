/* Reproducer: with V=1, VS-stage loads honour only vsstatus.MXR.
 *
 * sstatus is vsstatus while V=1, so mstatus.MXR must not make a VS-stage
 * execute-only page readable. Here the VS-stage page at VA 0x00100000 is
 * execute-only (R=0, X=1), mstatus.MXR=1 and vsstatus.MXR=0. The VS-mode load
 * must raise a load page fault (mcause 13). The core under test ORs in the
 * M-level mxr_i for the VS-stage check, so the load completes and the ecall
 * that follows traps with mcause 10 instead.
 * The G-stage is an identity 1 GiB mapping (U=1, R/W/X) for code and tables. */
#include "hyp.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  HGATP_ON

  /* VS-stage: identity 1 GiB leaf for code; VA 0 -> GPA 0x80000000 execute-only. */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  GIGA_LEAF(vs_root, 0, 0x80000000, (PTE_V | PTE_X | PTE_A | PTE_D))
  la t2, vs_root
  VSATP_ON(t2)

  /* mstatus.MXR = 1 (vsstatus.MXR stays 0). */
  li t0, (1 << 19)
  csrs mstatus, t0
  ENTER_VS(vs_user)

  .align 2
vs_user:
  li t0, 0x00100000
  ld a1, 0(t0)
  ecall

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 13                 /* load page fault */
  bne t0, t1, 1f
  PASS
1:
  FAIL(2)

  .section .data
  HYP_TABLES
