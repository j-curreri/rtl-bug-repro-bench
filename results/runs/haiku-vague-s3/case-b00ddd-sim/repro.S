#include "test.h"
#include "hyp.h"

/* An illegal instruction trapped from VS-mode into M-mode (medeleg = 0).
 * mtval holds the instruction bits, not a guest virtual address, so the
 * spec requires mstatus.GVA = 0, while mstatus.MPV = 1 (trapped from virtual mode). */
  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  csrw medeleg, zero
  csrw hedeleg, zero
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  HGATP_ON
  ENTER_VS(vs_code)

  .align 2
vs_code:
  .word 0xffffffff
  FAIL(9)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 2
  bne t0, t1, 1f
  csrr t0, mstatus
  srli t0, t0, 38
  andi t0, t0, 3
  li t1, 2
  bne t0, t1, 2f
  PASS
1:
  FAIL(1)
2:
  FAIL(2)

HYP_TABLES
