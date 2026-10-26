#include "test.h"

  .section .text
  .balign 4
  .globl test_main
test_main:
  /* Stay in M-mode with V=0.  No address translation is used by this test.
   *
   * A direct write to vsatp with V=0 differs from a guest's write to satp:
   * an unsupported MODE is handled as WARL, while ASID and PPN are written
   * normally.  It must not suppress the entire write as satp does.
   */
  csrw vsatp, zero

  /* Establish a nonzero, representable PPN with the supported Sv39 MODE.
   * 0x80000 is the PPN of DRAM at 0x80000000.  We never walk this root.
   */
  li t0, 0x8000000000080000
  csrw vsatp, t0
  csrr t1, vsatp
  bne t0, t1, setup_failed

  /* MODE=1 is unsupported on this RV64 Sv39 core; ASID=PPN=0 are legal.
   * A correct implementation may choose any legal MODE, so only examine
   * the other 60 bits.  The buggy handler ignores this whole write and
   * leaves the old nonzero PPN behind.
   */
  li t0, 0x1000000000000000
  csrw vsatp, t0
  csrr t1, vsatp
  slli t1, t1, 4
  bnez t1, write_failed

  csrw vsatp, zero
  PASS

write_failed:
  FAIL(1)
setup_failed:
  FAIL(2)

  .balign 4
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  FAIL(127)
