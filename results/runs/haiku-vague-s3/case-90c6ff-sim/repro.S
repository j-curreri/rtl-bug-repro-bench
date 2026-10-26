#include "hyp.h"

/* Reproducer: HLVX.HU in HS-mode through two-stage translation where the G-stage maps the
 * whole guest-physical region execute-only (X set, R and MXR clear).
 * The final access is an HLVX read, which execute permission allows, and the VS-stage
 * page-table reads are ordinary implicit reads made under the same HLVX. The G-stage
 * execute-only pages and VS-stage tables must not block this. On the buggy core the
 * implicit G-stage read of the VS-stage PTE is rejected (load guest page fault, mcause 21).
 *
 * Note: the spec reading that HLVX applies to implicit G-stage reads of the VS-stage walk is
 * the assumption this reproducer depends on. */
#define G_XONLY (PTE_V | PTE_X | PTE_U | PTE_A | PTE_D)

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  GIGA_LEAF(g_root, 2, 0x80000000, G_XONLY)
  HGATP_ON
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  la a1, vs_root
  VSATP_ON(a1)
  li t0, HSTATUS_SPVP
  csrs hstatus, t0
  la s1, probe
  ENTER_MODE(1, hs_code)

  .align 2
hs_code:
  hlvx.hu a2, (s1)
  ecall

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 9
  bne t0, t1, 1f
  li t1, 0x5a5a
  bne a2, t1, 2f
  PASS
1: slli t0, t0, 1
  ori a0, t0, 1
  j _halt
2: FAIL(2)

HYP_TABLES
  .align 3
probe: .dword 0x5a5a
