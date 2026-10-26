#include "test.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  /* Make sure this is a machine-mode test with a usable timer interrupt. */
  li t0, -1
  csrw pmpaddr0, t0
  li t0, 0x1f
  csrw pmpcfg0, t0

  la t0, trap_handler
  csrw mtvec, t0

  /* A trap must replace this stale value with zero for an interrupt. */
  li t0, 0x5a5a
  csrw mtval, t0
  li t0, 0x1234
  csrw mcause, t0

  /* Set mtimecmp relative to the current timer value so setup time is safe. */
  li t0, 0x0200bff8
  ld t1, 0(t0)
  li t2, 100000
  add t1, t1, t2
  li t0, 0x02004000
  sd t1, 0(t0)

  /* Enable machine timer interrupts, then wait for the asynchronous trap. */
  li t0, (1 << 7)
  csrw mie, t0
  csrsi mstatus, 8
wait_for_timer:
  j wait_for_timer
wait_for_timer_end:
  FAIL(1)

  .align 2
  .globl trap_handler
trap_handler:
  /* The only expected trap is machine timer interrupt (interrupt bit | 7). */
  csrr t0, mcause
  li t1, 0x8000000000000007
  bne t0, t1, fail_cause

  /* mepc must identify an instruction in the interrupt wait loop. */
  csrr t0, mepc
  la t1, wait_for_timer
  bltu t0, t1, fail_epc
  la t1, wait_for_timer_end
  bgeu t0, t1, fail_epc

  /* mtval is zero for an interrupt; the sentinel must not survive. */
  csrr t0, mtval
  bnez t0, fail_tval

  PASS

fail_cause:
  FAIL(2)
fail_epc:
  FAIL(3)
fail_tval:
  FAIL(4)
