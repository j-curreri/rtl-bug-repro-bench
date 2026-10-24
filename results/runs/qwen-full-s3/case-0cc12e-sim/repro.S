#include "test.h"

/*
 * Bug: after a synchronous environment-call (ecall) or breakpoint (ebreak)
 * exception, mtval does not match the privileged spec.
 *
 *   Spec / reference (Spike):  mtval = 0 for ENV_CALL_* and for an ebreak.
 *   This core:                 mtval = the (compressed/full) instruction
 *                              encoding of the trapping instruction (non-zero).
 *
 * The test raises an M-mode ecall and an M-mode ebreak, traps to the handler,
 * and verifies that mtval is 0 (or, per the spec's allowance, the virtual
 * address of the trapping instruction).  It also sanity-checks mcause/mepc.
 *
 * g_fail is a bitmask:  bit0 = any failure, bit1 = ecall failed, bit2 = ebreak failed.
 * On a correct core g_fail stays 0 -> PASS.  On this core it is non-zero -> FAIL.
 */

  .section .bss
  .align 3
  .globl g_test
g_test:     .dword 0          /* 1 = ecall test, 2 = ebreak test */
  .globl g_fail
g_fail:     .dword 0

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  la   t0, trap_handler
  csrw mtvec, t0

  li   t0, 0
  la   t1, g_fail
  sd   t0, 0(t1)

  /* ---- Test 1: M-mode ecall (cause 11) ---- */
  li   t0, 1
  la   t1, g_test
  sd   t0, 0(t1)
  .option push
  .option norvc                     /* force 32-bit so the handler skips 4 bytes */
  ecall
  .option pop
  /* handler mret's here */

  /* ---- Test 2: M-mode ebreak (cause 3) ---- */
  li   t0, 2
  la   t1, g_test
  sd   t0, 0(t1)
  .option push
  .option norvc
  ebreak
  .option pop
  /* handler mret's here */

  /* ---- final verdict ---- */
  la   t0, g_fail
  ld   t0, 0(t0)
  beqz t0, repro_pass
  slli t0, t0, 1
  ori  t0, t0, 1
  mv   a0, t0
  j _halt
repro_pass:
  PASS

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  csrr t1, mtval
  csrr t2, mepc
  addi t2, t2, 4             /* skip the 32-bit trapping instruction */

  la   t3, g_test
  ld   t4, 0(t3)            /* t4 = 1 or 2 */

  /* expected cause: 11 (ecall) for test 1, 3 (ebreak) for test 2 */
  li   t5, 11
  li   t6, 3
  li   a0, 1
  beq  t4, a0, th_cause_ok   /* if test==1 keep expected=11 */
  mv   t5, t6                /* else expected=3 */
th_cause_ok:
  bne  t0, t5, th_fail       /* mcause != expected -> fail */

  /* mtval must be 0 (spec).  Also accept the vaddr of the trapping
     instruction (mepc), which the spec permits. */
  beqz t1, th_restore
  addi a1, t2, -4           /* original mepc */
  beq  t1, a1, th_restore

th_fail:
  /* record which test failed: g_fail |= (1 << test_idx) | 1 */
  la   a2, g_fail
  ld   a3, 0(a2)
  li   a1, 1
  sl   a1, a1, t4           /* a1 = 1 << test_idx */
  ori  a1, a1, 1
  or   a3, a3, a1
  sd   a3, 0(a2)
th_restore:
  csrw mepc, t2
  mret
