#include "test.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* Case 1: MRET to S-mode with MPRV=1 and MPIE=MIE=0. Per the privileged spec,
   * an xRET to a less-privileged mode clears MPRV, so MPRV must read 0 afterwards. */
  li t0, (3 << 11) | (1 << 17) | (1 << 7) | (1 << 3)
  csrc mstatus, t0
  li t0, (1 << 11) | (1 << 17)
  csrs mstatus, t0
  la t0, s_code
  csrw mepc, t0
  li s11, 1
  mret

s_code:
  ecall
  FAIL(100)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t1, mstatus
  csrr t2, mcause
  li t3, 1
  beq s11, t3, case1
  li t3, 2
  beq s11, t3, case2
  FAIL(127)

case1:
  li t3, 9                     /* ecall from S-mode */
  bne t2, t3, fail5
  li t3, (1 << 17)
  and t4, t1, t3
  bnez t4, fail1               /* MPRV must be cleared by MRET to S */
  srli t4, t1, 11
  andi t4, t4, 3
  li t3, 1
  bne t4, t3, fail2            /* MPP saved by the trap must be S */
  andi t4, t1, (1 << 7)
  bnez t4, fail3               /* MPIE must equal MIE before the trap (0) */

  /* Set up case 2: MRET to U-mode with MPIE=1, MIE=0 -> MIE becomes 1. */
  li s11, 2
  li t0, (3 << 11) | (1 << 17) | (1 << 7) | (1 << 3)
  csrc mstatus, t0
  li t0, (1 << 7)
  csrs mstatus, t0
  la t0, u_code
  csrw mepc, t0
  mret

u_code:
  ecall
  FAIL(101)

case2:
  li t3, 8                     /* ecall from U-mode */
  bne t2, t3, fail5
  andi t4, t1, (1 << 7)
  beqz t4, fail6               /* MPIE must equal MIE (1) saved by the trap */
  srli t4, t1, 11
  andi t4, t4, 3
  bnez t4, fail7               /* MPP saved by the trap must be U */
  PASS

fail1:
  FAIL(1)
fail2:
  FAIL(2)
fail3:
  FAIL(3)
fail5:
  FAIL(5)
fail6:
  FAIL(6)
fail7:
  FAIL(7)
