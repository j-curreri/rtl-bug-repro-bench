/* Bug: when a machine-mode interrupt is taken, mtval does not always read as
 * zero in the trap handler. The privileged spec (and this core) require
 * mtval to be written with zero for interrupts.
 *
 * Strategy: make the machine timer interrupt pending (mtimecmp = 0 so
 * mtime >= mtimecmp always holds), enable MTIE and MIE, then spin. The
 * interrupt is taken in M-mode (cause 0x80000007). The handler checks that
 * mtval == 0; on this buggy core mtval holds the encoding of the instruction
 * that was being decoded when the interrupt was taken, so the program fails.
 */
#include "test.h"

  .globl test_main
test_main:
  la t0, trap_handler
  csrw mtvec, t0

  /* MIE off while we arm the interrupt */
  csrci mstatus, 8

  /* mtimecmp = 0 -> MTimer interrupt pending (mtime is always >= 0) */
  li t0, 0x02000000
  li t1, 0
  sd t1, 0(t0)

  /* enable MTIE, then global MIE */
  li t0, 0x80
  csrs mie, t0
  csrsi mstatus, 8

  /* The interrupt is taken somewhere from here on; mepc is one of these
   * instructions and all of them have a non-zero encoding. */
wait:
  addi t0, t0, 0
  addi t1, t1, 0
  j wait
  /* not reached: the interrupt never fired */

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  csrr t1, mtval

  /* mcause must be a machine-mode interrupt (bit XLEN-1 set) */
  srli t3, t0, 63
  beqz t3, rep_cause

  /* disarm the timer: mtimecmp = -1 */
  li t2, 0x02000000
  li t3, -1
  sd t3, 0(t2)

  /* For interrupts, mtval must be zero */
  bnez t1, rep_mtval

  /* correct behaviour */
  li a0, 1
  j _halt

rep_cause:
  /* mcause was not a machine-mode interrupt: report its low bits */
  andi a0, t0, 0x7f
  slli a0, a0, 1
  ori a0, a0, 1
  li t2, 0x100000
  add a0, a0, t2
  j _halt

rep_mtval:
  /* mtval != 0 after a machine-mode interrupt: report its low 20 bits */
  li t2, 0xfffff
  and a0, t1, t2
  slli a0, a0, 1
  ori a0, a0, 1
  li t2, 0x200000
  add a0, a0, t2
  j _halt
