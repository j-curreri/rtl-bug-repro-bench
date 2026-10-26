#include "hyp.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* The VS page table is in DRAM. Give its GPA an execute-only G-stage
   * mapping, so the implicit read of its PTE must fault. */
  GIGA_LEAF(g_root, 2, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A))
  GIGA_LEAF(vs_root, 0, 0x80000000, VS_RWX)

  HGATP_ON
  la t0, vs_root
  VSATP_ON(t0)

  /* HLVX uses a supervisor guest access when SPVP is set. */
  li t0, HSTATUS_SPVP
  csrs hstatus, t0
  li t0, MSTATUS_MPV
  csrc mstatus, t0

  /* Run as HS-S, then fetch a halfword from guest VA 0x1000. The guest
   * translation cannot get past the execute-only G-stage mapping of vs_root. */
  ENTER_MODE(1, do_hlvx)

do_hlvx:
  li t0, 0x1000
  hlvx.hu t1, (t0)
  /* A successful HLVX means the execute-only PTE read was incorrectly allowed. */
  FAIL(1)

  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 21                    /* load guest-page fault */
  beq t0, t1, expected_fault
  FAIL(2)
expected_fault:
  PASS

HYP_TABLES
