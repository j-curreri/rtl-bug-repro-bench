#include "test.h"

/* ECALL must write zero to mtval.  The buggy decoder leaves the instruction
 * encoding (0x00000073) in the exception's tval, and the CSR file copies it.
 * Stay in M-mode so no delegation, page tables, or PMP setup is needed.
 */
  .section .text
  .balign 4
  .globl test_main
test_main:
  csrw mie, zero
  li t0, 8
  csrc mstatus, t0

  /* A nonzero initial value also checks that the trap overwrites mtval. */
  li t0, 0x1234
  csrw mtval, t0
  li s0, 1

  .option push
  .option norvc
ecall_site:
  ecall
ecall_return:
  .option pop
  /* Only the checked trap handler can clear this flag. */
  bnez s0, bad_return
  PASS

  .balign 4
  .globl trap_handler
trap_handler:
  li t0, 1
  bne s0, t0, unexpected_trap
  csrr t0, mcause
  li t1, 11                     /* Environment call from M-mode. */
  bne t0, t1, unexpected_trap
  csrr t0, mepc
  la t1, ecall_site
  bne t0, t1, bad_epc
  csrr t0, mtval
  bnez t0, bad_tval

  li s0, 0
  la t0, ecall_return
  csrw mepc, t0
  mret

unexpected_trap:
  FAIL(1)
bad_epc:
  FAIL(2)
bad_tval:
  FAIL(3)
bad_return:
  FAIL(4)
