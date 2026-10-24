#include "test.h"

/*
 * Bug: after a *breakpoint* (ebreak, cause 3) or an *environment call*
 * (ecall, cause 11 in M-mode) this core writes the instruction *encoding*
 * into mtval instead of the virtual address of the faulting instruction,
 * which is what the RISC-V privileged spec requires.
 *
 *   decoder.sv  : instruction_o.ex.tval = <raw instruction word>
 *   csr_regfile : mtval_d = ex_i.tval   (ZERO_TVAL == 0 in the normal build)
 *
 * So on this core, after `ebreak`/`ecall` in M-mode:
 *   mtval == raw encoding  (0x9002 for c.ebreak, 0x00000073 for ecall)
 * whereas a spec-correct core has:
 *   mtval == mepc          (the virtual address of the faulting instruction)
 *
 * Test plan (run in M-mode):
 *   1. Execute ebreak.  In the trap handler check mcause==3 and that
 *      mtval is the faulting-instruction address (== mepc); a value of 0 is
 *      also tolerated since some implementations zero mtval for these.
 *      If accepted, mret past the instruction to resume at the ecall.
 *   2. Execute ecall.    Same check with mcause==11.  If accepted, mret.
 *   3. Reach PASS only if both mtval values were spec-acceptable.
 *
 * On a spec-correct core both checks pass  -> PASS.
 * On this buggy core the ebreak value is the encoding 0x9002, which is
 * neither mepc nor 0 -> the check fails -> FAIL.
 */

  .globl test_main
test_main:
  csrci mstatus, 8        /* clear MIE: run the test without M-mode interrupts */
  ebreak                  /* trap 1: breakpoint,  cause 3  */
  ecall                   /* trap 2: ecall from M-mode, cause 11 */
  PASS                    /* reached only if both mtval values were acceptable */

  .globl trap_handler
  .align 2
trap_handler:
  csrr  t0, mcause
  csrr  t1, mepc          /* virtual address of the faulting instruction */
  csrr  t2, mtval

  li    t3, 3             /* BREAKPOINT */
  beq   t0, t3, chk_tval
  li    t3, 11            /* ENV_CALL from M-mode */
  beq   t0, t3, chk_tval
  FAIL(3)                 /* unexpected trap cause */

chk_tval:
  li    t4, 0
  beq   t2, t4, resume    /* accept mtval == 0 */
  bne   t1, t2, bad       /* otherwise mtval must equal mepc */
  j     resume

resume:                   /* mret back, resuming past the faulting instruction */
  lw    t5, 0(t1)         /* instruction word at mepc */
  andi  t5, t5, 3
  li    t4, 3
  beq   t5, t4, resume_wide
  addi  t1, t1, 2         /* 16-bit (compressed): advance 2 bytes */
  csrw  mepc, t1
  mret
resume_wide:
  addi  t1, t1, 4         /* 32-bit: advance 4 bytes */
  csrw  mepc, t1
  mret

bad:
  FAIL(1)
