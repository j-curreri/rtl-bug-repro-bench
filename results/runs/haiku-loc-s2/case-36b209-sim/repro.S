#include "hyp.h"

/* Bug: in cva6_ptw.sv the DTLB permission check ORs the host mstatus.MXR (mxr_i)
 * into VS-stage (V=1) translation, so an execute-only guest page becomes readable
 * when only the host's MXR is set. Per the H-extension spec, VS-stage loads use
 * vsstatus.MXR alone. This program expects a load page fault (cause 13). */

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  # G-stage: GPA 1G@0x80000000 -> HPA same, full permissions (no MXR dependence)
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  HGATP_ON
  # VS-stage: VA 1G@0x80000000 -> GPA same, execute-only (R=0, X=1)
  GIGA_LEAF(vs_root, 2, 0x80000000, PTE_V | PTE_X | PTE_A | PTE_D)
  la t2, vs_root
  VSATP_ON(t2)
  # host (mstatus) MXR=1 while vsstatus.MXR stays 0
  li t0, (1 << 19)
  csrs mstatus, t0
  ENTER_VS(vs_code)

  .align 6
vs_code:
  li t0, 0x80001000
  ld t1, 0(t0)        # must fault: page is execute-only for VS-mode
  ecall               # reached only if the load wrongly succeeded
  nop
  nop

  .align 6
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 13           # load page fault
  beq t0, t1, 1f
  FAIL(2)
1:
  PASS

HYP_TABLES
