#include "test.h"

/* Sdtrig mcontrol6 with match=1 (NAPOT) on a naturally aligned 4 KiB range
 * starting at buf. A load from inside the range must raise a breakpoint
 * exception (mcause 3) because the trigger action is 0 (breakpoint).
 * On the buggy core the NAPOT match fails for nonzero bases, so the load
 * completes and the program falls through to FAIL. */

  .section .text
  .globl test_main
test_main:
  # Select trigger 0.
  li t0, 0
  csrw tselect, t0

  # tdata2 = NAPOT encoding of [buf, buf + 0x1000): base | (size/2 - 1).
  la t1, buf
  ori t2, t1, 0x7ff
  csrw tdata2, t2

  # tdata1: type=6 (mcontrol6) | match=1 (NAPOT) | M | load, action=0 (breakpoint).
  li t3, ((6 << 60) | (1 << 7) | (1 << 6) | (1 << 0))
  csrw tdata1, t3

  # Load from inside the range, at offset 0x800.
  li t5, 0x800
  add t5, t5, t1
  fence
  ld t4, 0(t5)

  # Trigger did not fire.
  FAIL(1)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t6, mcause
  li t5, 3
  bne t6, t5, 1f
  PASS
1:
  FAIL(2)

  .section .data
  .balign 4096
buf:
  .space 8192
