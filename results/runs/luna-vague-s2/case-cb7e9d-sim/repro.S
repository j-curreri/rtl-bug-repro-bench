#include "test.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  /* Match an aligned NAPOT region containing trap_site. */
  csrw tselect, zero
  la t0, trap_site
  ori t0, t0, 7            /* NAPOT region; trap_site is 32-byte aligned */
  csrw tdata2, t0
  li t0, 0x60000000000000c4 /* type=6, match=NAPOT, m=1, execute=1 */
  csrw tdata1, t0
  fence.i
  j trap_site

  .align 5
trap_site:
  /* The trigger must prevent this instruction from executing. */
  FAIL(2)

resume:
  PASS

  .align 12
  .globl trap_handler
trap_handler:
  csrw tdata1, zero        /* avoid retriggering on nearby handler code */
  csrr t0, mcause
  li t1, 3                 /* breakpoint */
  bne t0, t1, unexpected
  csrr t0, mepc
  la t1, trap_site
  bne t0, t1, unexpected
  la t0, resume
  csrw mepc, t0
  mret

unexpected:
  FAIL(3)
