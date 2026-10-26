#include "test.h"

  .globl test_main
  .globl trap_handler

test_main:
  PMP_ALLOW_ALL

  # Verify MPRV can be set in M-mode
  li t0, (1 << 17)
  csrs mstatus, t0
  csrr t1, mstatus
  srli t1, t1, 17
  andi t1, t1, 1
  beqz t1, 3f

  # Enter S-mode; mret should clear MPRV according to RISC-V spec
  ENTER_MODE(1, s_entry)

s_entry:
  ecall

  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 9          # Environment call from S-mode
  bne t0, t1, 2f

  # Check if MPRV (bit 17 of mstatus) was cleared by MRET
  csrr t0, mstatus
  srli t0, t0, 17
  andi t0, t0, 1
  bnez t0, 1f       # If still set, bug is reproduced -> FAIL

  # MPRV was cleared correctly -> PASS
  PASS

1:
  FAIL(1)           # Buggy: MPRV was not cleared by MRET

2:
  FAIL(2)           # Unexpected trap

3:
  FAIL(3)           # Failed to set MPRV initially
