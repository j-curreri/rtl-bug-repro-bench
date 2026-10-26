#include "test.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  la t0, stage
  sd zero, 0(t0)
  ENTER_MODE(0, user_start)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 8                    /* ECALL from U-mode */
  beq t0, t1, handle_ecall
  li t1, 3                    /* breakpoint */
  beq t0, t1, handle_breakpoint
  FAIL(1)

handle_ecall:
  /* The privileged spec requires mtval=0 for an environment call. */
  csrr t0, mtval
  bnez t0, fail_ecall_tval
  la t0, stage
  ld t1, 0(t0)
  beqz t1, first_ecall
  li t2, 2
  beq t1, t2, success_ecall
  FAIL(2)
first_ecall:
  li t1, 1
  sd t1, 0(t0)
  csrr t1, mepc
  addi t1, t1, 4
  csrw mepc, t1
  mret
success_ecall:
  PASS
fail_ecall_tval:
  FAIL(3)

handle_breakpoint:
  /* mtval must identify the address of the instruction that broke. */
  csrr t0, mtval
  csrr t1, mepc
  bne t0, t1, fail_breakpoint_tval
  la t0, stage
  ld t1, 0(t0)
  li t2, 1
  bne t1, t2, fail_breakpoint_stage
  li t1, 2
  sd t1, 0(t0)
  csrr t1, mepc
  addi t1, t1, 4
  csrw mepc, t1
  mret
fail_breakpoint_tval:
  FAIL(4)
fail_breakpoint_stage:
  FAIL(5)

  .align 2
user_start:
  .option push
  .option norvc
  ecall                         /* expected mtval = 0 */
  ebreak                        /* expected mtval = address of this instruction */
  ecall                         /* proves the breakpoint handler returned correctly */
  .option pop
1: j 1b

  .section .data
  .align 3
stage:
  .dword 0
