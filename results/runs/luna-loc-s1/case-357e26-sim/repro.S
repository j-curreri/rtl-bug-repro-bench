#include "test.h"

  .section .text
  .globl test_main
test_main:
  /*
   * With G=1, TOR pmpaddr[0] is WARL zero. Write it as one anyway.
   * The architectural upper bound is 0x80004000, but the buggy matcher
   * uses the raw CSR storage and extends the region through 0x80004003.
   */
  li t0, 0x20001001          /* (0x80004000 >> 2) | 1 */
  csrw pmpaddr0, t0
  li t0, 0x0f                 /* TOR, RWX */
  csrw pmpcfg0, t0

  /* The architectural CSR view also confirms bit 0 is zero in TOR mode. */
  csrr t1, pmpaddr0
  andi t1, t1, 1
  bnez t1, bad_readback

  ENTER_MODE(1, user_test)

bad_readback:
  FAIL(3)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 5                    /* load access fault */
  bne t0, t1, unexpected_trap
  PASS
unexpected_trap:
  FAIL(2)

  .align 2
user_test:
  /* Exactly at the aligned TOR upper bound: this must be denied. */
  li t0, 0x80004000
  ld t1, 0(t0)
  FAIL(1)

  .section .data
  .align 3
  .org 0x1000
  .dword 0x123456789abcdef0
  .dword 0
