#include "hyp.h"

/* VS-mode with vsatp = Bare and G-stage (Sv39x4) on. Guest-physical address
 * 0x40_8000_0000 has bit 38 set: it is a valid zero-extended 41-bit GPA, not a
 * Sv39 canonical VA. VS-mode fetches from it must not raise a page fault. */
#define ALIAS_OFF 0x4000000000

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* GPA 0x0_8000_0000 and GPA 0x40_8000_0000 both map to PA 0x8000_0000 */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 258, 0x80000000, G_RWX)
  csrw vsatp, zero
  HGATP_ON
  li t0, MSTATUS_MPV
  csrs mstatus, t0
  li t0, (3 << 11)
  csrc mstatus, t0
  li t0, (1 << 11)
  csrs mstatus, t0
  la t0, vs_code
  li t1, ALIAS_OFF
  add t0, t0, t1
  csrw mepc, t0
  mret

  .align 2
vs_code:
  li a1, 0x5a
  ecall
1: j 1b

  .align 2
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  li t5, 12            /* instruction page fault: the bug */
  beq t6, t5, 3f
  li t5, 10            /* environment call from VS-mode */
  bne t6, t5, 1f
  li t5, 0x5a
  bne a1, t5, 2f
  /* the ecall must have been executed from the high GPA alias */
  csrr t4, mepc
  li t2, ALIAS_OFF
  bltu t4, t2, 2f
  PASS
1:
  FAIL(1)
2:
  FAIL(2)
3:
  FAIL(3)

HYP_TABLES
