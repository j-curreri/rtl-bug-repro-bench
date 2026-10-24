/* repro.S -- bug reproducer for the CVA6 core (config cv64a6_imafdc_sv39).
 *
 * Bug: for synchronous exceptions raised by `ecall` and `ebreak` the mtval
 * register ends up holding the encoding of the faulting instruction instead
 * of the value mandated by the privileged specification:
 *
 *   - environment call (mcause 8/9/11): mtval must be 0
 *   - breakpoint (mcause 3):            mtval must be 0 or the faulting
 *                                       virtual instruction address
 *
 * On this core an M-mode `ecall` leaves mtval == 0x73 and an M-mode `ebreak`
 * leaves mtval == 0x100073 (both instruction encodings), which satisfies
 * neither requirement.  A spec-conformant core satisfies both.
 *
 * The program raises four exceptions (in M-, S- and U-mode) and validates
 * mcause and mtval in the trap handler after every one of them.  It ends
 * with PASS only if every exception looks spec-conformant.
 */

#include "test.h"

  .option norvc
  .text

/* ---------------------------------------------------------------------
 * Trap handler (mtvec is pointed here by the harness crt).
 *
 * The main program keeps the index of the trap it is about to provoke in
 * s0.  The handler checks the expected mcause and the spec-mandated mtval
 * and then resumes.  s0 is preserved; only t0-t3 are clobbered.
 * ---------------------------------------------------------------------
 */
  .globl trap_handler
  .align 3
trap_handler:
  csrr  t0, mcause
  bltz  t0, bad_int              /* no interrupts are enabled here */

  li    t1, 1                    /* phase 1: ecall from M-mode */
  beq   s0, t1, eh_m_ecall
  li    t1, 2                    /* phase 2: ebreak from M-mode */
  beq   s0, t1, eh_m_ebreak
  li    t1, 3                    /* phase 3: ecall from S-mode */
  beq   s0, t1, eh_s_ecall
  li    t1, 4                    /* phase 4: ecall from U-mode */
  beq   s0, t1, eh_u_ecall
  j     bad                      /* trap with no test in progress */

/* mcause 11, mtval must be 0 */
eh_m_ecall:
  li    t1, 11
  bne   t0, t1, bad_cause
  csrr  t2, mtval
  bnez  t2, bad_tval
  j     eh_step

/* mcause 3, mtval must be 0 or the address of the ebreak (== mepc) */
eh_m_ebreak:
  li    t1, 3
  bne   t0, t1, bad_cause
  csrr  t2, mtval
  beqz  t2, eh_step
  csrr  t3, mepc
  bne   t2, t3, bad_bpval
  j     eh_step

/* mcause 9, mtval must be 0 */
eh_s_ecall:
  li    t1, 9
  bne   t0, t1, bad_cause
  csrr  t2, mtval
  bnez  t2, bad_tval
  j     back_to_m3

/* mcause 8, mtval must be 0 */
eh_u_ecall:
  li    t1, 8
  bne   t0, t1, bad_cause
  csrr  t2, mtval
  bnez  t2, bad_tval
  j     back_to_m4

/* skip the 32-bit trapping instruction and continue after it */
eh_step:
  csrr  t0, mepc
  addi  t0, t0, 4
  csrw  mepc, t0
  mret

/* the S/U-mode segments never resume there: re-enter M-mode */
back_to_m3:
  li    t0, (3 << 11)
  csrs  mstatus, t0              /* mret returns to M-mode */
  la    t0, resume3
  csrw  mepc, t0
  mret
back_to_m4:
  li    t0, (3 << 11)
  csrs  mstatus, t0
  la    t0, resume4
  csrw  mepc, t0
  mret

/* ---------------------------------------------------------------------
 * Main: provoke the four traps.
 * ---------------------------------------------------------------------
 */
  .globl test_main
  .align 3
test_main:
  /* keep every trap in M-mode (medeleg/mideleg reset to 0 anyway) */
  csrw  mideleg, x0
  csrw  medeleg, x0

  /* allow S- and U-mode to execute and access the test image */
  PMP_ALLOW_ALL

  /* 1) environment call from M-mode */
  li    s0, 1
  ecall

  /* 2) breakpoint from M-mode */
  li    s0, 2
  ebreak

  /* 3) environment call from S-mode (not delegated, traps to M) */
  li    s0, 3
  ENTER_MODE(1, mode_s)
mode_s:
  ecall                           /* the handler never mrets back here */
  j     bad

resume3:
  /* 4) environment call from U-mode (not delegated, traps to M) */
  li    s0, 4
  ENTER_MODE(0, mode_u)
mode_u:
  ecall                           /* the handler never mrets back here */
  j     bad

resume4:
  PASS

/* failure exits; every FAIL(n) writes an odd, non-1 code to tohost */
bad_int:   FAIL(2)
bad:       FAIL(3)
bad_cause: FAIL(4)
bad_tval:  FAIL(5)
bad_bpval: FAIL(6)