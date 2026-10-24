#include "test.h"

/*
 * Bug: when a machine-mode interrupt is taken, mtval does not always read as
 * zero in the trap handler.  The privileged behaviour of this core is to
 * write zero into mtval for interrupts.
 *
 * In this RTL, on an M-mode trap the csr regfile computes
 *   mtval_d = ex_i.tval
 * because the "write zero" condition (which requires ariane_pkg::ZERO_TVAL to
 * be set) never holds for this configuration.  The decoder, however, preloads
 * the scoreboard entry's ex.tval with the instruction encoding of *every*
 * instruction (for illegal-instruction handling), and the interrupt path only
 * overrides ex.valid/ex.cause.  Hence an M-mode interrupt taken at
 * instruction X leaves mtval holding X's (non-zero) instruction encoding.
 *
 * Strategy:
 *  - in M-mode, make an M-mode interrupt pending using the CLINT at
 *    0x02000000: write mtimecmp = 0 (M timer) and msip = 1 (M software);
 *  - enable them (mie.MTIE|MSIE, mstatus.MIE);
 *  - spin: the pending interrupt is inserted into every instruction decoded
 *    while it is globally enabled, so the trap is taken at the spin
 *    instruction; every instruction that can be taken here (the spin jump,
 *    the flag load/branch, PASS/_halt) has a non-zero encoding, so the buggy
 *    core always leaves a non-zero mtval;
 *  - trap_handler verifies mcause is an M-mode interrupt and that mtval reads
 *    zero, records that the trap happened, clears both interrupt sources and
 *    mrets;
 *  - test_main PASSes only if the trap actually happened => a correct core
 *    ends with PASS.
 *  - on the buggy core the handler sees mtval != 0 => FAIL(2).
 */

  .section .data
  .align 2
trap_taken:
  .word 0

  .section .text
  .align 2
  .globl test_main
test_main:
  /* mtimecmp = 0 => M timer interrupt is pending (mtime >= mtimecmp) */
  li   t0, 0
  li   t4, 0x02004000
  sd   t0, 0(t4)
  /* msip = 1 => M software interrupt is pending */
  li   t0, 1
  li   t4, 0x02000000
  sw   t0, 0(t4)
  /* enable M software (bit 3) and M timer (bit 7) interrupts */
  li   t0, 0x38
  csrs mie, t0
  /* global M-mode interrupt enable (mstatus.MIE) */
  li   t1, 8
  csrs mstatus, t1
wait_irq:
  j    wait_irq
  /* reached only after the interrupt was handled and mret'ed */
  lw   a1, trap_taken
  beqz a1, 1f
  PASS
1:
  FAIL(3)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  csrr t1, mtval
  bgez t0, th_fail1          /* mcause[63] = 0: synchronous exception, unexpected */
  andi t0, t0, 31
  li   t2, 3                 /* M software */
  bne  t0, t2, th_cause7
  j    th_ok
th_cause7:
  li   t2, 7                 /* M timer */
  bne  t0, t2, th_cause11
  j    th_ok
th_cause11:
  li   t2, 11                /* M external */
  bne  t0, t2, th_fail1
th_ok:
  bnez t1, th_fail2          /* mtval must read zero for M-mode interrupts */
  /* remember that the interrupt was taken */
  li   t4, 1
  la   t3, trap_taken
  sw   t4, 0(t3)
  /* clear M timer: mtimecmp = -1 */
  li   t4, -1
  li   t3, 0x02004000
  sd   t4, 0(t3)
  /* clear M software: msip = 0 */
  li   t4, 0
  li   t3, 0x02000000
  sw   t4, 0(t3)
  mret
th_fail1:
  FAIL(1)
th_fail2:
  FAIL(2)
