#include "test.h"

/* mcontrol6 NAPOT store-address trigger (match=1).
 * Spec: compare the top M bits, M = XLEN-1 - index of the least-significant
 * 0 bit of tdata2, i.e. the trailing ones AND the first zero bit are ignored.
 * tdata2 = 0x7fffffff (lowest 0 bit = bit 31) therefore covers the whole
 * region [0, 2^32), so a store to buf (0x8000xxxx) must fire the trigger.
 * The buggy core still compares bit 31 (tdata2[31]=0 vs addr[31]=1) and
 * never fires. */

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  csrw medeleg, zero
  csrw satp, zero

  csrw tselect, zero
  csrr t0, tselect
  bnez t0, fail_setup

  li t1, 0x7fffffff
  csrw tdata2, t1
  csrr t2, tdata2
  bne t1, t2, fail_setup
  /* type=6, match=1 (NAPOT), s=1, store=1, action=0 (breakpoint exception) */
  li t0, (6 << 60) | (1 << 7) | (1 << 4) | 2
  csrw tdata1, t0
  csrr t2, tdata1
  bne t0, t2, fail_setup

  ENTER_MODE(1, smode)

smode:
  la t1, buf
  sd t1, 8(t1)
  ecall               /* trigger did not fire: wrong */

fail_setup:
  FAIL(1)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 3            /* breakpoint */
  bne t0, t1, 1f
  csrr t0, mstatus    /* trap must come from S-mode (MPP=1) */
  srli t0, t0, 11
  andi t0, t0, 3
  li t1, 1
  bne t0, t1, 1f
  PASS
1:
  FAIL(2)

  .data
  .align 6
buf:
  .dword 0x1111111111111111
  .dword 0x2222222222222222
