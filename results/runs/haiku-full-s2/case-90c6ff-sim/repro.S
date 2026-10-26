/* Reproducer: VS-mode (vsatp = Bare, hgatp = Sv39x4) fetches from a valid guest-physical
 * address with bit 38 set, i.e. a GPA whose bits [63:38] are not all equal. The buggy RTL
 * applies a VA sign-extension check to the GPA and raises a page fault. */
#include "hyp.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* GPA [0x4000000000, 0x7fffffffff] (1 GiB region idx 256) -> PA 0x80000000 */
  GIGA_LEAF(g_root, 256, 0x80000000, G_RWX)
  HGATP_ON
  csrw vsatp, zero

  /* mret into VS-mode (MPV=1, MPP=S) at GPA of vs_entry = PA(vs_entry) + 2^38 */
  li t0, MSTATUS_MPV
  csrs mstatus, t0
  li t0, (3 << 11)
  csrc mstatus, t0
  li t0, (1 << 11)
  csrs mstatus, t0
  la t0, vs_entry
  li t1, (1 << 38)
  add t0, t0, t1
  csrw mepc, t0
  mret

  .globl vs_entry
vs_entry:
  ecall                       /* ecall from VS-mode (cause 10) traps to M-mode */

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 10
  bne t0, t1, 1f
  PASS
1:
  FAIL(2)

HYP_TABLES
