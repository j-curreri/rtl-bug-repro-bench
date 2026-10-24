/*
 * repro.S - reproducer for the CVA6 (cv64a6_imafdc_sv39) mtval-on-interrupt bug.
 *
 * Bug: when a machine-mode interrupt is taken, mtval reads back as the encoding
 * of the interrupted instruction instead of zero.  In csr_regfile.sv the trap
 * entry path only zero-extends mtval when
 *      ZERO_TVAL && (cause inside {ILLEGAL_INSTR, BREAKPOINT, ECALL*} || cause[XLEN-1])
 * and ZERO_TVAL is 0 in this build, so mtval_d ends up as ex_i.tval.  For an
 * interrupt the decoder attaches the cause to the instruction currently being
 * decoded and leaves its ex.tval = instruction bits, so mtval becomes the
 * instruction encoding.  A spec-correct core writes mtval = 0 for interrupts.
 *
 * Method:
 *   1. enable machine software (MSIE) and machine timer (MTIE) interrupts,
 *   2. arm the CLINT comparator (mtimecmp = 0x10) as a backup trigger,
 *   3. raise the CLINT software interrupt line (msip = 1) as primary trigger,
 *   4. set mstatus.MIE and spin on plain (non-zero encoded) instructions.
 *
 * The first machine interrupt taken lands in trap_handler; there we only check
 * that mtval reads as zero.  Everything stays in machine mode with no delegation,
 * so any interrupt that fires is a machine-mode one.
 *
 * PASS  on a core that zeroes mtval for interrupts (spec-correct).
 * FAIL  on the buggy core (mtval = instruction bits != 0).
 */

#include "test.h"

  .section .text
  .align 2
  .globl test_main

/* CLINT (classic memory map) */
#define CLINT_MSIP            0x02000000
#define CLINT_MTIMECMP        0x02004000

/* CSRs / status bits */
#define MSTATUS_MIE_BIT       3
#define MIE_MSIE_BIT          3
#define MIE_MTIE_BIT          7
#define MIE_MEIE_BIT          11

test_main:
  /* 1. enable machine software + machine timer + machine external interrupts */
  li    t0, (1 << MIE_MSIE_BIT) | (1 << MIE_MTIE_BIT) | (1 << MIE_MEIE_BIT)
  csrw  mie, t0

  /* 2. backup trigger: mtimecmp = 0x10 so MTIP fires shortly after start
   *    (mtime counts up from 0).  Use two 32-bit stores (low half at +0x0,
   *    high half at +0x4) so it works on 64-bit-only and split 32-bit CLINT
   *    register implementations alike.  A small non-zero value works with
   *    both "mtimecmp == 0 means pending" and "mtimecmp == 0 means disabled"
   *    comparator styles - no need to read mtime at all. */
  li    t0, CLINT_MTIMECMP
  li    t1, 0x10
  sw    t1, 0(t0)
  sw    x0, 4(t0)

  /* 3. primary trigger: msip[0] = 1 -> machine software interrupt pending */
  li    t0, CLINT_MSIP
  li    t1, 1
  sw    t1, 0(t0)

  /* 4. interrupt globally enabled as last step, then wait for the trap. */
  li    t0, (1 << MSTATUS_MIE_BIT)
  csrs  mstatus, t0

1:
  addi  a5, a5, 1          /* plain instructions, all non-zero encodings, so
                             the interrupt can never attach to a zero tval */
  j     1b
  j     1b                 /* unreachable padding */

/* --------------------------------------------------------------------
 * Trap handler (mstatus.MPP=3, direct mtvec): we arrive here in M-mode.
 * Interrupt -> mtval must read as zero; anything else is unexpected.
 * -------------------------------------------------------------------- */
  .align 2
  .globl trap_handler
trap_handler:
  csrr  t3, mcause            /* keep the cause in t6 for debugging */
  bgez  t3, fail_unexpected_cause   /* bit 63 clear -> synchronous exception */
  csrr  t4, mtval             /* interrupt taken: mtval must be zero */
  beqz  t4, pass_i
  FAIL(2)                     /* mtval non-zero on interrupt -> bug reproduces */
pass_i:
  PASS

fail_unexpected_cause:
  FAIL(127)                   /* trap we did not expect */