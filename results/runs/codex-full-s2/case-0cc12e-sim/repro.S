#include "test.h"

  .section .text
  .option norvc
  .balign 4
  .globl test_main
test_main:
  /* Keep all traps in M-mode, with interrupts disabled. */
  csrw mie, zero
  csrci mstatus, 8
  csrw medeleg, zero

  /* ECALL must overwrite mtval with zero, even if it was nonzero. */
  li t0, 0x1234
  csrw mtval, t0
  la s0, ecall_site
ecall_site:
  ecall
  /* A correct ECALL cannot fall through without entering the handler. */
  FAIL(1)

  .balign 4
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 11                    /* Environment call from M-mode. */
  bne t0, t1, bad_cause
  csrr t0, mepc
  bne t0, s0, bad_pc
  csrr t0, mtval
  /* The buggy core supplies the ECALL encoding, 0x00000073. */
  bnez t0, bad_tval
  PASS

bad_cause:
  FAIL(2)
bad_pc:
  FAIL(3)
bad_tval:
  FAIL(4)
