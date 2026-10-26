#include "test.h"

  .option norvc
  .section .text
  .globl test_main
test_main:
  /* A misaligned load must report its address in mtval and its PC in mepc. */
  la t0, misaligned_addr
  addi t0, t0, 1
  la t1, misaligned_fault
  la t2, expected_pc
  sd t1, 0(t2)
  la t2, expected_tval
  sd t0, 0(t2)
  la t2, expected_cause
  li t3, 4
  sd t3, 0(t2)
misaligned_fault:
  ld t4, 0(t0)

  /* An M-mode ECALL must report cause 11, the ECALL PC, and the ECALL PC in mtval. */
  la t1, ecall_fault
  la t2, expected_pc
  sd t1, 0(t2)
  la t2, expected_tval
  sd t1, 0(t2)
  la t2, expected_cause
  li t3, 11
  sd t3, 0(t2)
ecall_fault:
  ecall

  PASS

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  la t1, expected_cause
  ld t1, 0(t1)
  bne t0, t1, fail_cause
  csrr t0, mepc
  la t1, expected_pc
  ld t1, 0(t1)
  bne t0, t1, fail_pc
  csrr t0, mtval
  la t1, expected_tval
  ld t1, 0(t1)
  bne t0, t1, fail_tval
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret
fail_cause:
  FAIL(1)
fail_pc:
  FAIL(2)
fail_tval:
  FAIL(3)

  .section .data
  .align 3
expected_pc: .dword 0
expected_tval: .dword 0
expected_cause: .dword 0
misaligned_addr: .dword 0x1122334455667788
