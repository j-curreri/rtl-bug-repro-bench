#include "test.h"

  .text
  .align 2
  .globl test_main
test_main:
  /*
   * Entry 0 allows [0, protected). Entry 1 denies [protected, protected+4).
   * protected is 4 mod 8, so pmpaddr0 (the TOR lower bound) has bit 0 set.
   * A load at the exclusive upper boundary must match entry 2 and be allowed.
   */
  la t0, protected
  srli t0, t0, 2
  csrw pmpaddr0, t0

  la t1, protected
  addi t1, t1, 4
  srli t1, t1, 2
  csrw pmpaddr1, t1

  li t2, -1
  csrw pmpaddr2, t2

  /* pmp0: RWX TOR; pmp1: deny TOR; pmp2: RWX TOR. */
  li t0, 0x0f080f
  csrw pmpcfg0, t0

  fence.i
  ENTER_MODE(0, user_test)

  .align 2
user_test:
  la t0, protected
  addi t0, t0, 4
  lw t1, 0(t0)
  PASS

failed:
  FAIL(1)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 5                    /* Load access fault */
  bne t0, t1, failed
  PASS

  .data
  .align 3
boundary:
  .word 0
protected:
  .word 0x13579bdf
  .word 0
