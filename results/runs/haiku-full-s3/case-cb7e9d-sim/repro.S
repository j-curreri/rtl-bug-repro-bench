#include "test.h"

/* Sdtrig mcontrol6 with match=1 (NAPOT) must fire for a store inside a naturally aligned
 * 16-byte region. Trigger 0 covers [data_buf, data_buf+16) via tdata2 = base | 0x7.
 * The store goes to data_buf+8: inside the range, not at its base. Stores are used
 * because the exact-match control shows loads hanging on this core. */
  .section .text
  .globl test_main
test_main:
  li t0, 0
  csrw tselect, t0
  la t0, data_buf
  ori t0, t0, 7
  csrw tdata2, t0
  /* mcontrol6: type=6, match=1 (NAPOT), m=1, store=1, action=0 (breakpoint) */
  li t0, ((6 << 60) | (1 << 7) | (1 << 6) | 2)
  csrw tdata1, t0
  la t1, data_buf
  sd t2, 8(t1)      /* inside the range, not at its base */
  FAIL(1)           /* no breakpoint raised: trigger did not fire */

  .globl trap_handler
  .align 2
trap_handler:
  csrr t6, mcause
  li t5, 3
  bne t6, t5, 1f
  csrr t6, mtval
  la t5, data_buf
  addi t5, t5, 8
  bne t6, t5, 2f
  PASS
1: FAIL(2)
2: FAIL(3)

  .data
  .align 4
data_buf: .dword 0x1111, 0x2222
