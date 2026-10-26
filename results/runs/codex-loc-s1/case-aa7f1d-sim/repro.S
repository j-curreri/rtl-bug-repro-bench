#include "test.h"

/*
 * U-mode may read cycle only when BOTH mcounteren.CY and scounteren.CY
 * are set.  With CY=1 in mcounteren and CY=0 in scounteren, rdcycle
 * must raise an illegal-instruction exception (Privileged ISA, scounteren).
 *
 * The RVH path in csr_regfile.sv instead combines the two disabled bits
 * with AND, allowing this read.  A successful read therefore fails here.
 */
  .section .text
  .balign 4
  .globl test_main
test_main:
  csrw mie, zero
  csrw medeleg, zero
  csrw mideleg, zero
  csrw satp, zero
  PMP_ALLOW_ALL

  li t0, 1
  csrw mcounteren, t0
  csrw scounteren, zero

  /* Enter ordinary U-mode, with virtualization and interrupts disabled. */
  li t0, ((1 << 39) | (1 << 17) | (1 << 7) | (1 << 3))
  csrc mstatus, t0
  ENTER_MODE(0, user_test)

  .balign 4
user_test:
  .option push
  .option norvc
forbidden_read:
  csrr t1, cycle
  .option pop
  FAIL(1)

  .balign 4
  .globl trap_handler
trap_handler:
  /* PASS only for the expected exception at the forbidden CSR read. */
  csrr t0, mcause
  li t1, 2
  bne t0, t1, unexpected_trap
  csrr t0, mepc
  la t1, forbidden_read
  bne t0, t1, unexpected_trap
  csrr t0, mstatus
  li t1, (3 << 11)
  and t0, t0, t1
  bnez t0, unexpected_trap
  PASS

unexpected_trap:
  FAIL(2)
