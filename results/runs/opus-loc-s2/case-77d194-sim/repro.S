/* Counter access from U-mode (V=0) must be gated by BOTH mcounteren and scounteren.
 * Privileged spec (Zicntr / scounteren): when scounteren.CY is clear, reading `cycle`
 * from U-mode raises an illegal-instruction exception, even if mcounteren.CY is set.
 * The buggy core combines the enables as ~mcounteren & ~scounteren, so the read
 * succeeds. */
#include "test.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  li t0, -1
  csrw mcounteren, t0        /* M allows S/U to see all counters */
  csrw scounteren, zero      /* S denies U access to all counters */
  li s0, 0                   /* s0 = 1 once the expected trap was seen */
  ENTER_MODE(0, user_code)

user_code:
  rdcycle a1                 /* must trap: illegal instruction */
  ecall                      /* report back to M-mode */

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 2                   /* illegal instruction */
  beq t0, t1, illegal
  li t1, 8                   /* ecall from U-mode */
  bne t0, t1, unexpected
  beqz s0, no_trap
  PASS
no_trap:
  FAIL(1)
unexpected:
  FAIL(2)
illegal:
  /* the faulting instruction must be the rdcycle */
  csrr t0, mepc
  la t1, user_code
  bne t0, t1, unexpected
  li s0, 1
  addi t0, t0, 4
  csrw mepc, t0
  mret
