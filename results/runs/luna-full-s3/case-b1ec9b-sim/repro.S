#include "test.h"

  .section .text
  .globl test_main
test_main:
  /* PMP TOR entry 0 allows S-mode access below 0x80400000. The test code,
     tohost, and stack all reside below that boundary. */
  li t0, 0x80400000
  srli t0, t0, 2
  csrw pmpaddr0, t0
  li t0, 0x0f              /* TOR, RWX */
  csrw pmpcfg0, t0

  /* M-mode can access this address while PMP denies it to S-mode. */
  li t0, 0x80401000
  li t1, 0x13579bdf
  sw t1, 0(t0)

  /* A conforming MRET clears MPRV when it returns to S-mode. */
  li t0, (1 << 17)
  csrs mstatus, t0
  ENTER_MODE(1, supervisor_entry)

supervisor_entry:
  ecall
  FAIL(2)                  /* The M-mode trap handler terminates the test. */

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 9                 /* Environment call from S-mode. */
  beq t0, t1, probe
  li t1, 5                 /* Load access fault from stale MPRV/PMP. */
  beq t0, t1, fail_probe
  FAIL(3)

probe:
  /* Correct M-mode access bypasses this unlocked PMP entry. If MPRV was
     incorrectly retained, the effective S-mode access is denied. */
  li t0, 0x80401000
  lw t1, 0(t0)
  li t2, 0x13579bdf
  bne t1, t2, fail_probe
  PASS

fail_probe:
  FAIL(4)
