#include "test.h"

  .text
  .globl test_main
test_main:
  /* Ensure clean M-mode trap environment and grant S/U RWX access via PMP */
  csrw mie, zero
  csrw medeleg, zero
  csrw satp, zero
  PMP_ALLOW_ALL

  li s5, 0                  /* bitmask of mtval spec violations */
  li s6, 0                  /* count of verified traps */

  /* 1. Environment call from M-mode (mcause = 11): mtval must be 0 */
  li s0, 11
  li s1, 0
  la s2, after_m_ecall
  la s3, m_ecall_insn
  li s4, (1 << 0)
  la t0, test_main
  csrw mtval, t0
m_ecall_insn:
  ecall
  FAIL(66)
after_m_ecall:

  /* 2. Environment call from S-mode (mcause = 9): mtval must be 0 */
  li s0, 9
  li s1, 0
  la s2, after_s_ecall
  la s3, s_ecall_insn
  li s4, (1 << 1)
  la t0, test_main
  csrw mtval, t0
  ENTER_MODE(1, s_ecall_insn)
s_ecall_insn:
  ecall
  FAIL(67)
after_s_ecall:

  /* 3. Environment call from U-mode (mcause = 8): mtval must be 0 */
  li s0, 8
  li s1, 0
  la s2, after_u_ecall
  la s3, u_ecall_insn
  li s4, (1 << 2)
  la t0, test_main
  csrw mtval, t0
  ENTER_MODE(0, u_ecall_insn)
u_ecall_insn:
  ecall
  FAIL(68)
after_u_ecall:

  /* 4. Uncompressed ebreak in M-mode (mcause = 3): mtval must be 0 or mepc */
  li s0, 3
  li s1, 1
  la s2, after_ebreak32
  la s3, ebreak32_insn
  li s4, (1 << 3)
  la t0, test_main
  csrw mtval, t0
  .option push
  .option norvc
ebreak32_insn:
  ebreak
  .option pop
  FAIL(69)
after_ebreak32:

  /* 5. Compressed c.ebreak in M-mode (mcause = 3): mtval must be 0 or mepc */
  li s0, 3
  li s1, 1
  la s2, after_ebreak16
  la s3, ebreak16_insn
  li s4, (1 << 4)
  la t0, test_main
  csrw mtval, t0
  .option push
  .option rvc
ebreak16_insn:
  c.ebreak
  .option pop
  FAIL(70)
after_ebreak16:

  /* Ensure all 5 traps occurred */
  li t0, 5
  bne s6, t0, missing_traps

  /* Fail if any trap wrote a non-compliant value to mtval */
  bnez s5, fail_mtval

  PASS

fail_mtval:
  slli a0, s5, 1
  ori a0, a0, 1
  j _halt

missing_traps:
  FAIL(71)

  .globl trap_handler
  .balign 4
trap_handler:
  csrr t0, mcause
  bne t0, s0, bad_cause

  csrr t1, mepc
  bne t1, s3, bad_mepc

  csrr t2, mtval
  beqz s1, check_ecall_mtval

  /* Breakpoint: RISC-V Privileged Spec allows mtval == 0 or mtval == faulting VA (mepc) */
  beqz t2, trap_resume
  beq t2, t1, trap_resume
  or s5, s5, s4
  j trap_resume

check_ecall_mtval:
  /* Environment call: RISC-V Privileged Spec requires mtval == 0 */
  beqz t2, trap_resume
  or s5, s5, s4

trap_resume:
  addi s6, s6, 1
  li t0, (3 << 11)
  csrs mstatus, t0
  csrw mepc, s2
  mret

bad_cause:
  FAIL(64)

bad_mepc:
  FAIL(65)
