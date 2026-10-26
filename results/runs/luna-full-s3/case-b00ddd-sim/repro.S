#include "hyp.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Map VA 0x80000000 through both stages to the DRAM physical address. */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)

  /* hgatp uses an Sv39x4 root; vsatp uses the guest physical VS root. */
  HGATP_ON
  la t0, vs_root
  VSATP_ON(t0)

  /* Execute an unsupported custom-0 instruction while in VS-mode. CV-X-IF
     sees it as an offloaded instruction and reports it as illegal. */
  ENTER_VS(vs_code)

  .align 2
vs_code:
  .word 0x0000707b
1: j 1b

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 2                       /* illegal instruction */
  bne t0, t1, trap_fail
  csrr t0, mstatus
  li t1, MSTATUS_GVA
  and t0, t0, t1
  bnez t0, trap_fail             /* GVA must be clear for this exception */
  csrr t0, mstatus
  li t1, MSTATUS_MPV
  and t0, t0, t1
  beqz t0, trap_fail             /* Confirm the trap came from VS-mode */
  PASS
trap_fail:
  FAIL(1)

  HYP_TABLES
