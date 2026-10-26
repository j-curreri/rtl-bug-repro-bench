#include "test.h"
#include "hyp.h"

/* Fetch from a guest-physical address above 2^39 with VS-stage in Bare mode and
 * G-stage (Sv39x4) enabled. Sv39x4 GPAs are 41 bits, so the fetch must succeed.
 * The G-stage maps GPA 0x80_0000_0000 (root index 512) to PA 0x80000000 with a 1 GiB leaf. */

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  GIGA_LEAF(g_root, 512, 0x80000000, G_RWX)
  HGATP_ON
  csrw vsatp, zero

  /* mepc = GPA of vs_main = 0x80_0000_0000 + (vs_main - 0x80000000) */
  la t0, vs_main
  li t1, 0x80000000
  sub t0, t0, t1
  li t1, 0x8000000000
  add t0, t0, t1
  csrw mepc, t0

  /* mret into VS-mode: MPP = S, MPV = 1 */
  li t0, (3 << 11)
  csrc mstatus, t0
  li t0, (1 << 11)
  csrs mstatus, t0
  li t0, MSTATUS_MPV
  csrs mstatus, t0
  mret

  .align 2
vs_main:
  li a0, 0
  ecall

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 10
  bne t0, t1, 7f
  PASS
7: slli a0, t0, 1
  ori a0, a0, 1
  j _halt

HYP_TABLES
