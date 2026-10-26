#include "test.h"
#include "hyp.h"

/* Reproducer: when V=1, VS-stage loads must use vsstatus.MXR, not mstatus/sstatus.MXR.
 * Setup: mstatus.MXR=1, vsstatus.MXR=0. VS-stage VA 0 maps an execute-only page (X=1, R=0).
 * A VS-mode load from that page must raise a load page fault (cause 13).
 * The buggy PTW ORs in the HS-level mxr_i for S-stage, so the load succeeds. */

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  GIGA_LEAF(g_root, 0, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(vs_root, 0, 0x0, PTE_V | PTE_X | PTE_A | PTE_D)
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  fence
  HGATP_ON
  la t2, vs_root
  VSATP_ON(t2)

  li t0, (1 << 19)
  csrs mstatus, t0
  csrc vsstatus, t0

  la s0, probe
  li t1, 0x80000000
  sub s0, s0, t1
  ENTER_VS(vs_code)

  .align 2
vs_code:
  ld a0, 0(s0)
  ecall

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 13
  bne t0, t1, 1f
  PASS
1: FAIL(2)

  .section .data
  .align 3
probe: .dword 0x1234567890abcdef

HYP_TABLES
