#include "test.h"
#include "hyp.h"

  HYP_TABLES

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* Map GVA[2^38 : 2^39) -> PA[0x80000000:0x80400000).  Top-level G-stage
   * index for GVA in this range is 256; the GVA has bit 38 set. */
  GIGA_LEAF(g_root, 256, 0x80000000, G_RWX)
  HGATP_ON
  csrw vsatp, zero
  la t0, vs_code
  li t1, 0x380000000        /* GVA = PA + 0x380000000 = 0x400000000 - 0x80000000 */
  add t0, t0, t1
  li t3, 0x1800
  csrc mstatus, t3         # clear MPP
  li t3, 0x0800
  csrs mstatus, t3         # MPP = S
  li t2, MSTATUS_MPV
  csrs mstatus, t2         # MPV = 1  -> mret into VS-mode
  csrw mepc, t0
  mret

vs_code:
  addi a1, zero, 1
  addi a1, a1, 1
  addi a1, a1, 1
  PASS

  .globl trap_handler
  .align 2
trap_handler:
  csrr a0, mcause
  slli a0, a0, 1
  ori a0, a0, 1
  la t0, tohost
  sd a0, 0(t0)
1: j 1b
