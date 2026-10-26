#include "hyp.h"

/* G-stage leaf with X only (no R, no W): execute-only guest page. */
#define G_XONLY (PTE_V | PTE_X | PTE_U | PTE_A | PTE_D)

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* G-stage: GPA 0x80000000 -> PA 0x80000000 (RWX), GPA 0xC0000000 -> PA 0x80000000 (X only). */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 3, 0x80000000, G_XONLY)
  HGATP_ON
  csrw vsatp, zero

  /* HLV/HLVX act with the privilege given by hstatus.SPVP; use S. */
  li t0, HSTATUS_SPVP
  csrs hstatus, t0

  /* Guest address of `probe`: PA + 0x40000000 through the X-only mapping. */
  la s0, probe
  li t0, 0x40000000
  add s0, s0, t0

  /* HLVX reads an execute-only page: must succeed and fill the TLB. */
hlvx_insn:
  hlvx.hu a1, (s0)

  /* Plain HLV read of the same execute-only page: must raise a load guest page fault. */
hlv_insn:
  hlv.w a1, (s0)
  FAIL(1)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 21                 /* load guest page fault */
  bne t0, t1, bad_cause
  la t1, hlv_insn
  csrr t2, mepc
  bne t2, t1, bad_epc
  PASS
bad_cause:
  FAIL(2)
bad_epc:
  FAIL(3)

  HYP_TABLES

  .data
  .align 3
probe: .dword 0x1234567887654321
