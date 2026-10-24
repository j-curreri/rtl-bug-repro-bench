/*
 * Bug reproducer: mtval is not zeroed for environment-call and breakpoint
 * exceptions.
 *
 * RISC-V privileged spec: mtval must be 0 for traps that carry no faulting
 * address - environment calls (any privilege mode) and breakpoints.  This
 * core instead writes the offending instruction encoding into mtval for
 * those causes (decoder sets ex.tval = instruction encoding for decode-stage
 * exceptions and csr_regfile only clears it when ariane_pkg::ZERO_TVAL is
 * compiled in): an M-mode ecall leaves mtval = 0x73, an M-mode ebreak
 * leaves mtval = 0x00100073 instead of 0.
 *
 * The test traps on ecall/ebreak from M, S and U mode.  The m-level trap
 * handler checks
 *   - mcause against the privilege mode recorded in mstatus.MPP at trap
 *     entry (MPP is written by the core hardware, so no test state is kept
 *     in GPRs and stray debug-mode excursions in this harness cannot corrupt
 *     the test state),
 *   - that mtval == 0, which is what the spec requires for ecall/breakpoint
 *     and where this core is buggy,
 * and then resumes right after the trapping instruction by re-writing
 * mepc+4 (ecall/ebreak are kept 4 bytes) and mret; mret re-enters the same
 * mode recorded in MPP for causes 11/3/8, or drops to U-mode (MPP -> 0)
 * after the S-mode case, which is the last one.
 */

#include "test.h"

  .text
  .align 2
  .globl test_main
test_main:
  /* Let S/U modes touch memory (tohost, code). */
  PMP_ALLOW_ALL

  /* Spec-conformant cores write 0 to mtval for env calls and breakpoints;
     one that merely leaves the old value there also starts out at 0. */
  csrw mtval, x0

  /* T0: ECALL in M-mode   -> mcause 11 (ENV_CALL_MMODE), mtval == 0 */
  ecall

  /* T1: EBREAK in M-mode  -> mcause 3  (BREAKPOINT),      mtval == 0 */
  .option push
  .option norvc
  ebreak                       /* keep a 4-byte instr; handler adds 4 */
  .option pop

  /* T2: ECALL in S-mode   -> mcause 9  (ENV_CALL_SMODE),  mtval == 0.
     The handler then clears mstatus.MPP and mret's straight into U-mode. */
  ENTER_MODE(1, smode_part)
  FAIL(30)                     /* never reached: mret entered S-mode */

smode_part:
  ecall
  FAIL(31)                     /* never reached */

umode_part:
  /* T3: ECALL in U-mode   -> mcause 8  (ENV_CALL_UMODE),  mtval == 0.
     The handler resumes here (mepc+4), still in U-mode. */
  ecall
  PASS                         /* ecall is taken by the trap, not this path */
  FAIL(32)                     /* unreachable */

/* ------------------------------------------------------------------ */
/* Machine trap handler.  Valid traps here, with the privilege mode the  */
/* trap came from stored by hardware in mstatus.MPP:                    */
/*   MPP=3: mcause 3 (EBREAK) or 11 (M-mode ECALL),     mtval must be 0 */
/*   MPP=1: mcause 9 (S-mode ECALL),                    mtval must be 0 */
/*   MPP=0: mcause 8 (U-mode ECALL),                    mtval must be 0 */
/* Anything else fails.  After the S-mode case the handler clears MPP and */
/* returns into U-mode; for every other case it resumes at mepc+4.      */
/* ------------------------------------------------------------------ */
  .align 2
  .globl trap_handler
trap_handler:
  csrr t6, mcause              /* left in t6 for post-mortem in traces */
  csrr t1, mstatus
  srli t1, t1, 11
  andi t1, t1, 3               /* t1 = MPP = privilege mode that trapped */

  /* dispatch on the trapping privilege mode */
  li   t0, 3
  beq  t1, t0, mmode_src
  li   t0, 1
  beq  t1, t0, smode_src
  beqz t1, umode_src
  FAIL(2)                      /* MPP neither 3/1/0: impossible */

mmode_src:                     /* EBREAK (3) or M-mode ECALL (11) */
  li   t0, 11
  beq  t6, t0, check_mtval
  li   t0, 3
  beq  t6, t0, check_mtval
  j    bad_cause

smode_src:                     /* S-mode ECALL (9) */
  li   t0, 9
  bne  t6, t0, bad_cause
  j    check_mtval

umode_src:                     /* U-mode ECALL (8); falls through */
  li   t0, 8
  bne  t6, t0, bad_cause

check_mtval:                   /* ecall/ebreak must leave mtval == 0 */
  csrr t2, mtval
  beqz t2, mtval_ok
  FAIL(1)                      /* mtval != 0 -> the bug */

mtval_ok:
  li   t0, 1
  bne  t1, t0, resume_next     /* not the S-mode case: resume at mepc+4 */
  la   t3, umode_part          /* S-mode case: drop straight into U-mode */
  csrw mepc, t3
  li   t0, 0x1800
  csrc mstatus, t0             /* mstatus.MPP -> 0 (U-mode) */
  mret

resume_next:
  csrr t3, mepc
  addi t3, t3, 4
  csrw mepc, t3
  mret

bad_cause:
  FAIL(2)