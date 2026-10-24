#include "test.h"

/*
 * Reproducer for an mtval bug on synchronous exceptions.
 *
 * The RISC-V privileged spec fixes the value written to the machine trap value
 * register (mtval, because both traps are taken in M-mode) for these causes:
 *
 *   - Environment call (mcause 8/9/11):  mtval = 0
 *   - Breakpoint       (mcause 3):       mtval = address of the ebreak instruction (= mepc)
 *
 * On a spec-conforming core both checks below hold and the program ends with PASS.
 *
 * On the buggy core the instruction-encoding bits are written to mtval for these
 * causes instead of the value the spec requires (empirically, mtval = 0x73 after
 * the M-mode ecall and a value that is neither 0 nor the ebreak's address after
 * the ebreak), so the checks fail and the program ends with FAIL(n).
 *
 * test_main simply issues the two trapping instructions back to back; the trap
 * handler validates mtval for each, then advances mepc past the 4-byte ecall /
 * ebreak and mret's so control continues at the next test (and finally at PASS).
 *
 * Everything runs in M-mode, so no PMP / S- or U-mode setup is needed.
 */

  .section .text
  .globl test_main
test_main:
  /* Test 1: environment call from M-mode -> mtval must be 0. */
  ecall

  /* Test 2: breakpoint -> mtval must equal the address of the ebreak (= mepc). */
  ebreak

  /* Reached by mret from the ebreak handler after both checks passed. */
  PASS

/*
 * Trap handler.
 *   a0 = mcause, a1 = mepc (address of the trapping instruction), a2 = mtval
 */
  .globl trap_handler
  .align 2
trap_handler:
  csrr a0, mcause
  csrr a1, mepc
  csrr a2, mtval

  li   t0, 11                 /* ENV_CALL_MMODE */
  beq  a0, t0, check_ecall
  li   t0, 3                  /* BREAKPOINT */
  beq  a0, t0, check_ebreak
  FAIL(5)                    /* a trap we did not expect */

check_ecall:
  /* mtval must be 0 for an environment call */
  bnez a2, ecall_bad
  addi a1, a1, 4
  csrw mepc, a1
  mret
ecall_bad:
  FAIL(3)                    /* ecall: mtval != 0 */

check_ebreak:
  /* mtval must be the address of the ebreak instruction (= mepc) */
  bne  a2, a1, ebreak_bad
  addi a1, a1, 4
  csrw mepc, a1
  mret
ebreak_bad:
  FAIL(4)                    /* ebreak: mtval != mepc */
