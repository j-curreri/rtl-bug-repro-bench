/* Reproducer: MXR must not make G-stage execute-only pages readable for a plain
 * hypervisor load (HLV, not HLVX). The G-stage leaf for GPA 0xC0000000 is X-only, and
 * vsstatus.MXR=1 permits VS-stage execute-only reads only. A correct core raises a load
 * guest-page fault (cause 21). cva6_ptw.sv applies mxr_i to G-stage leaves too and reads it. */
#include "test.h"
#include "hyp.h"

#define G_XONLY (PTE_V | PTE_X | PTE_U | PTE_A | PTE_D)

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* G-stage: GPA 0x80000000 identity-mapped (page tables and code live here). */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  /* G-stage: GPA 0xC0000000 -> HPA 0x80000000, execute-only. */
  GIGA_LEAF(g_root, 3, 0x80000000, G_XONLY)
  /* VS-stage: VA 0x80000000 -> GPA 0xC0000000, readable. */
  GIGA_LEAF(vs_root, 2, 0xC0000000, VS_RWX)
  HGATP_ON
  la t0, vs_root
  VSATP_ON(t0)
  li t0, HSTATUS_SPVP
  csrs hstatus, t0
  /* MXR in sstatus and vsstatus. */
  li t0, (1 << 19)
  csrs sstatus, t0
  csrs vsstatus, t0
  /* Plain HLV (not HLVX): the G-stage page needs R, so this must fault. */
  li a1, 0x80000000
  hlv.d a0, (a1)
  FAIL(1)

  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 21
  bne t0, t1, 1f
  PASS
1: FAIL(2)

HYP_TABLES
