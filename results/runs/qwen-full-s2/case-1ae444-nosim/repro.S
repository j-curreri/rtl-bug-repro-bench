#include "test.h"

/* Reproduce the machine-mode-interrupt mtval bug.
 *
 * The privileged spec (and this core's contract) requires mtval to be written
 * with zero when a machine-mode interrupt is taken.  In csr_regfile.sv the
 * "trap to machine mode" path computes
 *
 *     mtval_d = (ariane_pkg::ZERO_TVAL
 *                && (cause inside {...} || cause[XLEN-1])) ? '0 : ex_i.tval;
 *
 * i.e. the "zero tval for interrupts" term (cause[XLEN-1]) is gated behind
 * ariane_pkg::ZERO_TVAL.  That parameter is 0 in this build, so the whole
 * condition is false and mtval latches ex_i.tval instead of zero.  For an
 * interrupt ex_i.tval is the bits of the instruction the interrupt was
 * delivered at (see decoder.sv), which is non-zero.  A correct core zeroes
 * mtval for machine-mode interrupts, so the handler below asserts mtval == 0
 * after taking a machine interrupt; the buggy core leaves it non-zero.
 */

  .section .text
  .globl test_main
  .align 2
test_main:
  /* Arm a machine timer interrupt: MTIMECMP = 0 so that MTIME >= MTIMECMP. */
  li   t0, 0x02004004        /* CLINT MTIMECMP[0] */
  sd   x0, 0(t0)
  /* Arm a machine software interrupt as well (MSIP = 1) so the interrupt is
   * definitely taken no matter which CLINT register is wired to the core. */
  li   t0, 0x0200400C        /* CLINT MSIP[0] */
  li   t1, 1
  sd   t1, 0(t0)
  fence iorw, iorw

  /* Enable M-timer + M-software (mie bits 7 and 3) and global M-mode
   * interrupts (mstatus.MIE, bit 3).  The trap is then taken at the next
   * instruction boundary and redirected to trap_handler (mtvec). */
  li   t0, 0x88              /* MTIE | MSIP */
  csrs mie, t0
  li   t0, 0x8               /* MIE */
  csrs mstatus, t0

1:  j    1b                  /* keep executing until the machine interrupt */

  /* Override the weak default trap handler defined in crt.S. */
  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li   t1, 0x8000000000000007   /* M-mode timer interrupt cause */
  beq  t0, t1, check_mtval
  li   t1, 0x8000000000000003   /* M-mode software interrupt cause */
  beq  t0, t1, check_mtval
  FAIL(127)                    /* some other trap -> not our interrupt */
check_mtval:
  csrr t0, mtval
  bnez t0, bad_mtval          /* mtval != 0 -> the bug */
  PASS
bad_mtval:
  FAIL(7)
