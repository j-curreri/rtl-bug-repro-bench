#include "test.h"
#include "hyp.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Delegate illegal-instruction exceptions to HS, but not to VS. */
  li t0, (1 << 2)
  csrw medeleg, t0
  la t0, hs_trap_handler
  csrw stvec, t0

  /* Identity-map DRAM through both stages with 1 GiB leaves. */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  HGATP_ON
  la t0, vs_root
  VSATP_ON(t0)

  li t0, MSTATUS_MPV
  csrs mstatus, t0
  li t0, (3 << 11)
  csrc mstatus, t0
  li t0, (1 << 11)
  csrs mstatus, t0
  la t0, vs_test
  csrw mepc, t0
  mret

vs_test:
  /*
   * Custom-3 opcode, deliberately unsupported by the example coprocessor.
   * An illegal-instruction trap reports the instruction in stval; it is not
   * a trap caused by a guest virtual address, so HSTATUS.GVA must be clear.
   */
  .word 0x0000007b
  FAIL(1)                    /* It must trap before reaching this point. */

  .align 2
hs_trap_handler:
  csrr t0, scause
  li t1, 2
  bne t0, t1, hs_fail
  csrr t0, hstatus
  andi t0, t0, 0x40          /* HSTATUS.GVA */
  bnez t0, hs_fail
  PASS
hs_fail:
  FAIL(2)

  HYP_TABLES
