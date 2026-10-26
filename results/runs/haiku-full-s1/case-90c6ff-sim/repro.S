#include "hyp.h"

/* VS-mode fetch from a valid Sv39x4 guest-physical address with bit 38 set and
 * bits 39..40 clear. Bit 38 is the lowest bit where the MMU's canonical-address
 * check (VLEN-1 down to SV-1) looks, so a correct core fetches here and the buggy
 * core raises an instruction page fault. */

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Guest GPA [2^38, 2^38 + 1 GiB) -> host DRAM [0x80000000, +1 GiB). */
  GIGA_LEAF(g_root, 256, 0x80000000, G_RWX)
  HGATP_ON

  /* mepc = guest VA of vs_code: its host address plus 2^38. */
  la t0, vs_code
  li t1, 0x80000000
  sub t0, t0, t1
  li t1, 0x4000000000
  add t0, t0, t1
  csrw mepc, t0

  /* mret to VS-mode (MPP=S, MPV=1). vsatp is Bare after reset. */
  li t0, (3 << 11)
  csrc mstatus, t0
  li t0, (1 << 11)
  csrs mstatus, t0
  li t0, MSTATUS_MPV
  csrs mstatus, t0
  mret

vs_code:
  /* Reached only if the fetch succeeds: VS-mode ecall (cause 10). */
  ecall
  j vs_code

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 10
  bne t0, t1, 1f
  PASS
1:
  FAIL(1)

HYP_TABLES
