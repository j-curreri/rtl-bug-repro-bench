#include "hyp.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Map the top Sv39x4 1 GiB GPA region onto the DRAM region containing
     this program.  Its base has GPA[40] set, which is a valid 41-bit GPA. */
  GIGA_LEAF(g_root, 1024, 0x80000000, G_RWX)
  HGATP_ON

  /* The VS-stage is deliberately Bare. */
  csrw vsatp, zero
  hfence.vvma

  /* The link address of guest_code is its backing physical address.  Convert
     it to the corresponding GPA within the 1 TiB mapping above. */
  la t0, guest_code
  li t1, 0x80000000
  sub t0, t0, t1
  li t1, 0x10000000000
  add t0, t0, t1
  csrw mepc, t0

  /* MRET with MPP=S and MPV=1 enters VS-mode. */
  li t0, (3 << 11)
  csrc mstatus, t0
  li t0, (1 << 11) | (1 << 39)
  csrs mstatus, t0
  mret

  .align 2
guest_code:
  /* Reaching this instruction proves instruction fetch worked at GPA[40]=1. */
  PASS

  .align 2
  .globl trap_handler
trap_handler:
  /* Any trap, including an instruction guest-page fault, is a failure. */
  FAIL(127)

  HYP_TABLES
