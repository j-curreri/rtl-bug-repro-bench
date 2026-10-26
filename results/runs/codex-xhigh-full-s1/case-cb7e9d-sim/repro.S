#include "test.h"

/* RV64 mcontrol6: action=0 (breakpoint), select=0 (address),
 * size=0 (any), dmode=0.  Only U-mode loads are enabled. */
#define MC6_DISABLED  0x6000000000000000
#define MC6_LOAD_EQ   0x6000000000000009
#define MC6_LOAD_NAPOT 0x6000000000000089

  .section .text
  .option norvc
  .balign 4
  .globl test_main
test_main:
  csrwi mie, 0
  csrwi medeleg, 0
  csrwi satp, 0
  li t0, 8
  csrc mstatus, t0
  PMP_ALLOW_ALL

  li s2, 0                       /* Number of validated breakpoint traps. */
  la s3, watched
  addi s3, s3, 8                 /* Interior byte, never the encoded address. */
  csrwi tselect, 0
  li t0, MC6_DISABLED
  csrw tdata1, t0

  /* Control: an exact address match must reach the same trap handler. */
  csrw tdata2, s3
  la s0, exact_load              /* Expected faulting PC. */
  la s1, exact_done              /* Resume in M-mode here after the trap. */
  li t0, MC6_LOAD_EQ
  csrw tdata1, t0
  ENTER_MODE(0, exact_load)

exact_done:
  li t0, 1
  bne s2, t0, bad_count

  /* Sdtrig NAPOT: five trailing ones encode a 64-byte aligned range.
   * watched is 64-byte aligned; watched+8 is strictly inside the range.
   * The nonzero high address bits expose the faulty NAPOT validity test. */
  la t0, watched
  ori t0, t0, 31
  csrw tdata2, t0
  la s0, napot_load
  la s1, napot_done
  li t0, MC6_LOAD_NAPOT
  csrw tdata1, t0
  ENTER_MODE(0, napot_load)

napot_done:
  li t0, 2
  bne s2, t0, bad_count
  PASS

exact_load:
  lbu t2, 0(s3)
  FAIL(1)                       /* Exact trigger did not fire. */

napot_load:
  lbu t2, 0(s3)
  FAIL(2)                       /* NAPOT trigger did not fire: reported bug. */

  .balign 4
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 3                      /* Breakpoint exception, not an access fault. */
  bne t0, t1, unexpected_trap
  csrr t0, mepc
  bne t0, s0, unexpected_trap

  /* Disable before returning; retain type=6 while clearing all enables. */
  li t0, MC6_DISABLED
  csrw tdata1, t0
  addi s2, s2, 1
  csrw mepc, s1
  li t0, (3 << 11)
  csrs mstatus, t0               /* MPP=M for the continuation. */
  mret

unexpected_trap:
  FAIL(3)
bad_count:
  FAIL(4)

  .section .data
  .balign 64
watched:
  .zero 64
