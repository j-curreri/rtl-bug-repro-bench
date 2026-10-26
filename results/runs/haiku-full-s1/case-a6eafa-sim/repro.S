/* Reproducer: HLVX must not use execute permission for the implicit VS-stage PTE read.
 *
 * The VS-stage root table lives at guest-physical 0xC0000000 + vs_root_offset, which the
 * G-stage maps execute-only (X, no R). The VS-stage leaf for the flag word is RWX, so the
 * only way for HLVX to fail is the implicit PTE read. That read is an ordinary load and
 * must raise a load guest-page fault (mcause 21). The buggy core lets it succeed.
 */
#include "test.h"
#include "hyp.h"

#define PTE_XONLY (PTE_V | PTE_X | PTE_U | PTE_A | PTE_D)
#define CAUSE_LOAD_GUEST_PAGE_FAULT 21

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* G-stage: GPA 0x80000000 -> HPA 0x80000000 (RWX), GPA 0xC0000000 -> HPA 0x80000000 (X only). */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 3, 0x80000000, PTE_XONLY)
  HGATP_ON

  /* VS-stage: VA 0x80000000 -> GPA 0x80000000 (RWX). Root table is at GPA 0xC0000000 + offset. */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  la t2, vs_root
  li t3, 0x40000000
  add t2, t2, t3
  VSATP_ON(t2)

  /* Run HLVX from HS-mode with hstatus.SPVP=1, so the access uses VS-stage permissions. */
  li t0, HSTATUS_SPVP
  csrs hstatus, t0
  li t0, MSTATUS_MPV
  csrc mstatus, t0
  ENTER_MODE(1, hs_hlvx)

hs_hlvx:
  la a1, flag
  hlvx.hu a0, 0(a1)
  /* No trap: the implicit PTE read was allowed by execute permission. */
  FAIL(1)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, CAUSE_LOAD_GUEST_PAGE_FAULT
  bne t0, t1, 1f
  PASS
1:
  FAIL(2)

HYP_TABLES

  .data
  .align 3
flag: .dword 0x1234
