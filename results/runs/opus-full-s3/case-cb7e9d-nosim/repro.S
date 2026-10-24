#include "test.h"

/* Bug: mcontrol6 NAPOT (match=1) address triggers never fire for addresses
 * inside the range. Set a NAPOT load-address trigger covering a 128-byte
 * aligned buffer (tdata2 = buf | 0x3f) and load from inside it in U-mode.
 * A correct core raises a breakpoint exception (mcause 3) before the load. */

/* mcontrol6: type=6, action=0 (breakpoint), match=1 (NAPOT), u=1, load=1 */
#define MC6_NAPOT_LOAD_U  ((6 << 60) | (1 << 7) | (1 << 3) | (1 << 0))

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  csrw tselect, zero
  csrw tdata1, zero
  la t0, buf
  ori t0, t0, 0x3f
  csrw tdata2, t0
  li t0, MC6_NAPOT_LOAD_U
  csrw tdata1, t0
  ENTER_MODE(0, user)

user:
  la t2, buf
  ld t3, 8(t2)        /* inside the NAPOT range: must raise breakpoint */
  FAIL(1)             /* trigger did not fire */

  .globl trap_handler
  .align 2
trap_handler:
  csrw tdata1, zero
  csrr t6, mcause
  li t5, 3            /* breakpoint */
  bne t6, t5, 1f
  PASS
1:
  FAIL(3)

  .section .data
  .align 7
buf:
  .dword 0x1111, 0x2222, 0x3333, 0x4444
