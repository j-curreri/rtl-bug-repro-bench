/* Reproducer for trap CSR bug on interrupt (CVA6 / cv64a6_imafdc_sv39).
 *
 * RISC-V Privileged Architecture (e.g. v20211203, Section 3.1.16 & 4.1.9):
 * "When a trap is taken into M-mode, mtval is either set to zero or written with
 * exception-specific information to assist software in handling the trap.
 * Otherwise, mtval is set to zero... For other traps, mtval is set to zero."
 * Similarly for stval on traps taken into S-mode.
 *
 * In this buggy core (core/csr_regfile.sv):
 * mtval_d and stval_d are updated using:
 *   (ariane_pkg::ZERO_TVAL && (... || ex_i.cause[XLEN-1])) ? '0 : ex_i.tval;
 * Since ZERO_TVAL is 0 (SPIKE_TANDEM is not defined), the condition is always
 * false, causing mtval and stval to hold ex_i.tval (the instruction word of the
 * interrupted instruction) instead of 0 upon taking an interrupt.
 */

#include "test.h"

  .globl test_main
  .globl trap_handler

test_main:
  PMP_ALLOW_ALL

  /* --- Stage 1: Test M-mode interrupt and mtval --- */

  /* Ensure mtval is 0 before interrupt */
  csrw mtval, zero

  /* Enable machine software interrupt (mie.MSIE = bit 3) */
  li t0, (1 << 3)
  csrs mie, t0

  /* Enable global interrupts in mstatus (mstatus.MIE = bit 3) */
  csrsi mstatus, 8

  /* Write 1 to CLINT msip register (0x02000000) */
  li t0, 0x02000000
  li t1, 1
  sw t1, 0(t0)

wait_m_irq:
  j wait_m_irq

stage2_entry:
  /* --- Stage 2: Test S-mode interrupt and stval --- */

  /* Disable MSIE so no further M-mode interrupts */
  li t0, (1 << 3)
  csrc mie, t0

  /* Ensure stval is 0 before interrupt */
  csrw stval, zero

  /* Delegate supervisor software interrupt (bit 1) to S-mode */
  li t0, (1 << 1)
  csrs mideleg, t0
  csrs sie, t0

  la t0, s_trap_handler
  csrw stvec, t0

  ENTER_MODE(1, in_smode)

in_smode:
  /* Enable interrupts in sstatus (sstatus.SIE = bit 1) */
  csrsi sstatus, 2

  /* Trigger supervisor software interrupt via sip.SSIP (bit 1) */
  li t0, (1 << 1)
  csrs sip, t0

wait_s_irq:
  j wait_s_irq

  /* --- S-mode Trap Handler --- */
  .align 2
s_trap_handler:
  /* Clear sip.SSIP */
  li t0, (1 << 1)
  csrc sip, t0

  /* Verify scause is supervisor software interrupt */
  csrr a1, scause
  bgez a1, fail_cause
  slli a2, a1, 1
  srli a2, a2, 1
  li a3, 1
  bne a2, a3, fail_cause

  /* Check stval: privileged spec requires 0 on interrupt */
  csrr a4, stval
  bnez a4, fail_stval

  PASS

  /* --- M-mode Trap Handler --- */
  .align 2
trap_handler:
  /* Verify mcause is machine software interrupt */
  csrr a1, mcause
  bgez a1, fail_cause
  slli a2, a1, 1
  srli a2, a2, 1
  li a3, 3
  bne a2, a3, fail_cause

  /* Clear the CLINT msip register */
  li t0, 0x02000000
  sw zero, 0(t0)

  /* Check mtval: privileged spec requires 0 on interrupt */
  csrr a4, mtval
  bnez a4, fail_mtval

  /* Return to stage2_entry */
  la t0, stage2_entry
  csrw mepc, t0
  mret

fail_cause:
  FAIL(2)

fail_mtval:
  FAIL(1)

fail_stval:
  FAIL(3)
