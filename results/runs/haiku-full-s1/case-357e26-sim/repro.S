#include "test.h"

/* PMP entry 0 is TOR with upper bound `probe` (8-byte aligned, so G=1 means bit 0 of
 * pmpaddr is ignored and the true top bound is `probe`). A U-mode load at `probe` lies
 * outside the region and must fault. The buggy core treats bit 0 as address bit 2 and
 * extends the region to probe+4, so the load succeeds. */

  .section .data
  .balign 8
probe: .dword 0x1234

  .section .text
  .globl test_main
test_main:
  la t0, probe
  srli t0, t0, 2
  ori  t0, t0, 1          # pmpaddr0 = (probe >> 2) | 1 : lowest bit set
  csrw pmpaddr0, t0
  li t0, 0x0f             # entry 0: A=TOR (0x08), R|W|X (0x07)
  csrw pmpcfg0, t0
  ENTER_MODE(0, user_code)

user_code:
  la t0, probe
  ld t1, 0(t0)            # must fault on a correct core
  ecall                   # reached only if the load was allowed

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 5                # load access fault: the expected outcome
  bne t0, t1, 1f
  PASS
1:
  FAIL(1)
