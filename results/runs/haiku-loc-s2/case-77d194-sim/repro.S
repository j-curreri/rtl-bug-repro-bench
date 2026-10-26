#include "test.h"

/* Reproducer: U-mode access to a counter (cycle) needs both mcounteren[CY] and
 * scounteren[CY] set (Privileged spec, Sec. 3.1.11 / 3.1.12 counter access rules).
 * Here mcounteren[CY]=1 and scounteren[CY]=0, so `csrr cycle` in U-mode must raise an
 * illegal-instruction exception (cause 2). On this core the read succeeds and the
 * following ecall (cause 8) is reached instead. */

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  li t0, 1
  csrw mcounteren, t0
  csrw scounteren, zero
  ENTER_MODE(0, u_code)

u_code:
  csrr t1, cycle
  ecall

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 2                      /* illegal instruction: expected for csrr cycle in U-mode */
  bne t0, t1, 1f
  PASS
1:
  li t1, 8                      /* ecall reached: the counter read did not trap */
  bne t0, t1, 2f
  FAIL(8)
2:
  FAIL(3)
