#include "test.h"

  .section .text
  .globl test_main
test_main:
  # Set a supervisor software interrupt while in M-mode, but leave it
  # undelegated so it is handled in M-mode.
  li t0, (1 << 1)
  csrw mie, t0
  li t0, (1 << 1)
  csrw mip, t0

  # Enable global M-mode interrupts. The following instruction has a nonzero
  # encoding if incorrectly copied into mtval.
  li t0, (1 << 3)
  csrs mstatus, t0
1:
  j 1b

  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 0x8000000000000001
  bne t0, t1, unexpected_trap

  # Clear the software pending bit before checking the value.
  csrw mip, zero
  csrr t0, mtval
  bnez t0, bad_mtval
  PASS

unexpected_trap:
  FAIL(1)
bad_mtval:
  FAIL(2)
