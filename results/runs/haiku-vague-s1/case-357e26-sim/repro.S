#include "test.h"

/* PMP entry 0 is NA4 (4 bytes at `target`) with no permissions and has the highest
 * priority. Entry 1 is NAPOT over all memory with RWX. An S-mode load from `target`
 * must match entry 0 and fault. The buggy core never matches NA4 entries, so entry 1
 * grants the load and the program fails. */

  .section .data
  .align 3
target: .dword 0x1234

  .section .text
  .globl test_main
test_main:
  /* entry 0: NA4 (A=2), no R/W/X. entry 1: NAPOT (A=3), R/W/X. */
  la t0, target
  srli t0, t0, 2
  csrw pmpaddr0, t0
  li t0, -1
  csrw pmpaddr1, t0
  li t0, 0x1f10
  csrw pmpcfg0, t0

  ENTER_MODE(1, s_main)

s_main:
  la t0, target
  ld t1, 0(t0)           /* must raise a load access fault (mcause 5) */
  FAIL(2)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 5
  bne t0, t1, 1f
  PASS
1:
  FAIL(3)
