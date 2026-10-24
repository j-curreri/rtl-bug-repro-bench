#include "test.h"

/* MRET from M to S must clear mstatus.MPRV (privileged spec, MRET semantics).
 * Set MPRV=1, MRET into S-mode, ECALL back to M, then check MPRV == 0. */

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  csrw satp, zero
  li t0, (1 << 17)          /* MPRV */
  csrs mstatus, t0
  csrr t1, mstatus
  and t1, t1, t0
  beqz t1, skip             /* MPRV not writable: nothing to test */
  ENTER_MODE(1, s_code)

s_code:
  ecall                     /* back to M */
1: j 1b

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 9                  /* ecall from S */
  bne t0, t1, bad_trap
  csrr t0, mstatus
  li t1, (1 << 17)
  and t0, t0, t1
  bnez t0, fail_mprv
  PASS
fail_mprv:
  FAIL(5)
bad_trap:
  FAIL(2)
skip:
  FAIL(3)
