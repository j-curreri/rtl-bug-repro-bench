/* Reproducer for: "When a machine-mode interrupt is taken, mtval does not
 * always read as zero in the trap handler."
 *
 * Per the RISC-V privileged spec, mtval is written with 0 when an interrupt
 * is taken. A correct core therefore always reads mtval == 0 at the start of
 * a machine-mode interrupt handler.
 *
 * Test plan (all in M-mode):
 *   1. Prime mtval with a known non-zero value so a missing zero-clear is
 *      visible even if the stale value were the only symptom.
 *   2. Raise a machine-mode timer interrupt via the CLINT (mtimecmp = 0 so
 *      mtime >= mtimecmp is always true).
 *   3. In the trap handler, confirm mcause == M-TIME and that mtval == 0.
 *
 * Correct core  -> mtval is 0 after the M-interrupt   -> PASS
 * Buggy core    -> mtval is non-zero after M-interrupt -> FAIL
 */
#include "test.h"

  .equ CLINT,    0x02000000
  .equ MSIP,     CLINT + 0x0000
  .equ MTIMECMP, CLINT + 0x4000
  .equ MTIME,    CLINT + 0xBFF8

  .equ MTIE,        (1 << 7)   /* mie.MTIE      */
  .equ MIE,         (1 << 3)   /* mstatus.MIE   */
  .equ MTIME_CAUSE, 0x8000000000000007

  .section .data
irq_seen: .word 0

  .text
  .globl test_main
test_main:
  /* initialize the "handled" flag */
  la t2, irq_seen
  li t3, 0
  sw t3, 0(t2)

  /* prime mtval with a known non-zero value */
  li t5, 0x400
  csrw mtval, t5

  /* enable the M-mode timer interrupt */
  li t0, MTIE
  csrs mie, t0

  /* make M-TIME pending: mtimecmp = 0 => mtime >= mtimecmp */
  li t0, MTIMECMP
  li t1, 0
  sd t1, 0(t0)
  fence
  nop

  /* enable global M-mode interrupts */
  li t0, MIE
  csrs mstatus, t0

  /* spin until the handler reports it handled the interrupt */
wait_loop:
  la t2, irq_seen
  lw t2, 0(t2)
  beqz t2, wait_loop
  PASS

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, MTIME_CAUSE
  bne t0, t1, fail_not_timer
  csrr t0, mtval
  bnez t0, fail_mtval
  /* clear the pending source so we do not re-enter */
  li t2, MTIMECMP
  li t3, -1
  sd t3, 0(t2)
  /* signal main */
  la t2, irq_seen
  li t3, 1
  sw t3, 0(t2)
  mret
fail_not_timer:
  FAIL(4)
fail_mtval:
  FAIL(5)
