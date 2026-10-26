#include "hyp.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* GPA 0x10000000000 is a valid 41-bit Sv39x4 address (root index 1024).
   * Map its 1 GiB region onto the DRAM region containing vs_entry. */
  GIGA_LEAF(g_root, 1024, 0x80000000, G_RWX)
  HGATP_ON

  /* VS-stage translation is Bare. */
  csrw vsatp, zero
  hfence.vvma

  /* Enter VS at the high GPA alias of vs_entry. */
  li t0, 0x10000000000
  la t1, vs_entry
  la t2, _start
  sub t1, t1, t2
  add t0, t0, t1
  csrw mepc, t0
  li t0, (1 << 39)             /* mstatus.MPV */
  csrs mstatus, t0
  li t0, (3 << 11)
  csrc mstatus, t0
  li t0, (1 << 11)             /* mstatus.MPP = S; MPV selects VS */
  csrs mstatus, t0
  mret

  .option push
  .option norvc
  .align 2
vs_entry:
  ecall
1: j 1b
  .option pop

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 10                    /* environment call from VS-mode */
  bne t0, t1, trap_fail
  PASS
trap_fail:
  FAIL(127)

  HYP_TABLES
