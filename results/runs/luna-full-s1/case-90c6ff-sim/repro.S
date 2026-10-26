#include "hyp.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* GPA 0x10000000000 is bit 40 of the 41-bit Sv39x4 space. */
  GIGA_LEAF(g_root, 1024, 0x80000000, G_RWX)

  HGATP_ON

  /* Enter VS-mode with vsatp left Bare and start at the high GPA alias. */
  li t0, MSTATUS_MPV
  csrs mstatus, t0
  li t0, (3 << 11)
  csrc mstatus, t0
  li t0, (1 << 11)
  csrs mstatus, t0
  la t0, guest_entry
  li t1, 0x10000000000
  li t2, 0x80000000
  sub t0, t0, t2
  add t0, t0, t1
  csrw mepc, t0
  mret

  .align 2
guest_entry:
  /* Reaching this instruction proves G-stage translated the high GPA fetch. */
  li a0, 1
  li t0, 0x10000001000 /* tohost at GPA 1 TiB + 0x1000 */
  sd a0, 0(t0)
1: j 1b

  .globl trap_handler
  .align 2
trap_handler:
  csrr a0, mcause
  slli a0, a0, 1
  ori a0, a0, 1
  j _halt

  HYP_TABLES
