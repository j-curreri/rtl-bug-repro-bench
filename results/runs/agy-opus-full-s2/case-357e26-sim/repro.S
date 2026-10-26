/*
 * Reproducer: PMP TOR entry with pmpaddr[0] set (G=1, 8-byte grain).
 *
 * With G=1, pmpaddr[0] must be ignored in TOR mode (it reads as zero and the
 * region boundary is 8-byte aligned). Entry 0 is TOR [0, D) RWX where
 * pmpaddr0 = (D >> 2) | 1, entry 1 is TOR [D, top) with no permissions.
 *
 * A U-mode load from D must match entry 1 and raise a load access fault
 * (mcause 5) on a correct core. The buggy core uses the raw pmpaddr0 value,
 * so entry 0 spans [0, D+4) and the load at D succeeds.
 */
#include "test.h"

  .text
  .globl test_main
test_main:
  /* entry 0: TOR, top = D with lowest bit set */
  la   t0, boundary
  srli t0, t0, 2
  ori  t0, t0, 1
  csrw pmpaddr0, t0
  /* entry 1: TOR, top = all memory */
  li   t0, -1
  csrw pmpaddr1, t0
  /* cfg0 = TOR|RWX (0x0f), cfg1 = TOR, no permissions (0x08) */
  li   t0, 0x080f
  csrw pmpcfg0, t0
  sfence.vma
  fence.i

  li   s0, 0              /* phase: 0 = sanity load, 1 = boundary load */
  ENTER_MODE(0, user_code)

  .align 2
user_code:
  la   t1, below          /* D - 8: inside entry 0, must succeed */
  ld   t2, 0(t1)
  li   s0, 1
  la   t1, boundary       /* D: inside entry 1, must fault */
  ld   t2, 0(t1)
  li   s0, 2
  ecall                   /* reached only if the load did not fault */

  .globl trap_handler
  .align 2
trap_handler:
  csrr t6, mcause
  li   t5, 5              /* load access fault */
  bne  t6, t5, 1f
  li   t5, 1
  bne  s0, t5, 2f         /* fault on the sanity load -> unexpected */
  PASS
1:
  FAIL(1)                 /* e.g. ecall from U: boundary load was allowed */
2:
  FAIL(2)

  .data
  .align 3
below:
  .dword 0x1111111111111111
boundary:
  .dword 0x2222222222222222
  .dword 0
