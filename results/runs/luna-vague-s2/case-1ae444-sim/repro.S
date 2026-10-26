#include "test.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  la t0, trap_handler
  csrw mtvec, t0

  /* Make a machine timer interrupt pending before enabling it. */
  li t0, 0x02004000          /* CLINT mtimecmp */
  sd zero, 0(t0)
  li t0, (1 << 7)            /* mie.MTIE */
  csrs mie, t0
  li t0, (1 << 3)            /* mstatus.MIE */
  csrs mstatus, t0
timer_wait:
1: j 1b

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 0x8000000000000007
  bne t0, t1, fail_cause

  csrr t0, mtval
  bnez t0, fail_tval

  csrr t0, mepc
  la t1, timer_wait
  bne t0, t1, fail_epc

  csrr t0, mstatus
  srli t1, t0, 7             /* MPIE must record prior MIE=1 */
  andi t1, t1, 1
  beqz t1, fail_status
  srli t1, t0, 11            /* MPP must record prior M privilege */
  andi t1, t1, 3
  li t2, 3
  bne t1, t2, fail_status
  andi t1, t0, 8             /* MIE is cleared on trap entry */
  bnez t1, fail_status

  PASS
fail_cause:
  FAIL(1)
fail_tval:
  FAIL(2)
fail_epc:
  FAIL(3)
fail_status:
  FAIL(4)
