#include "test.h"

/* Reproducer: an M-mode ECALL must write mtval = 0 (privileged spec: mtval is zero for
 * exceptions that do not define a trap value). This core writes the instruction bits
 * (0x00000073) into mtval for ECALL instead. */

  .section .data
  .align 3
saved_cause: .dword -1
saved_tval:  .dword -1

  .section .text
  .globl trap_handler
  .align 2
trap_handler:
  la t5, saved_cause
  csrr t6, mcause
  sd t6, 0(t5)
  csrr t6, mtval
  sd t6, 8(t5)
  /* skip the 4-byte ecall */
  csrr t6, mepc
  addi t6, t6, 4
  csrw mepc, t6
  mret

  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* sentinel: if the core leaves mtval untouched, the handler sees this value */
  li t0, 0x5a5a
  csrw mtval, t0
  ecall

  la t0, saved_cause
  ld t1, 0(t0)
  li t2, 11
  bne t1, t2, 1f          /* the trap must be an environment call from M-mode */
  ld t1, 8(t0)
  bnez t1, 1f             /* ...and mtval must be zero */
  PASS
1:
  FAIL(1)
