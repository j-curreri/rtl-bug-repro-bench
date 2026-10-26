#include "test.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  ENTER_MODE(1, supervisor_test)

supervisor_test:
  /* UBE is part of sstatus and should be writable by S-mode. */
  li t0, 0x40
  csrw sstatus, t0
  csrr t0, sstatus
  andi a0, t0, 0x40
ecall_site:
  ecall

  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 9                    /* environment call from S-mode */
  bne t0, t1, unexpected_trap
  csrr t0, mepc
  la t1, ecall_site
  bne t0, t1, unexpected_trap
  bnez a0, expected_result
  FAIL(1)
expected_result:
  PASS

unexpected_trap:
  FAIL(2)
