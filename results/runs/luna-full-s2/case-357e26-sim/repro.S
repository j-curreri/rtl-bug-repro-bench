#include "test.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  /*
   * Entry 0 allows the code and ends at data_boundary.  Entries 1 and 2 are
   * TOR entries: entry 1 should be empty (its upper bound is rounded down to
   * data_boundary), and entry 2 denies accesses starting there.
   *
   * pmpaddr1 is deliberately written with bit 0 set while entry 1 is OFF.
   * The buggy matcher uses that raw bit and extends entry 1 by four bytes, so
   * the U-mode word load at data_boundary is incorrectly allowed by entry 1.
   */
  la t0, data_boundary
  srli t0, t0, 2              /* entry 0 upper bound, eight-byte aligned */
  csrw pmpaddr0, t0
  ori t1, t0, 1               /* boundary + 4 bytes; bit 0 must be ignored for G=1 */
  csrw pmpaddr1, t1
  addi t1, t0, 4               /* entry 2 upper bound, boundary + 16 bytes */
  csrw pmpaddr2, t1

  li t0, 0x080b0f             /* e0 TOR/RWX, e1 TOR/RW, e2 TOR/no permissions */
  csrw pmpcfg0, t0

  ENTER_MODE(0, u_test)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 5                    /* load access fault: correct PMP denial */
  bne t0, t1, unexpected_trap
  PASS
unexpected_trap:
  FAIL(2)

  .align 2
u_test:
  la t0, data_boundary
  lw t1, 0(t0)                /* should fault on a correct core */
  FAIL(1)                     /* reaching here exposes the TOR boundary bug */

  .section .data
  .balign 8
data_boundary:
  .word 0x12345678
