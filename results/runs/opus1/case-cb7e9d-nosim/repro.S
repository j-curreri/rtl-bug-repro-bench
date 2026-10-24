/* Reproducer: mcontrol6 load-address trigger with match=1 (NAPOT) must fire
 * for a load anywhere inside the configured naturally aligned range.
 *
 * Trigger 0: tdata2 = buf | 7  -> NAPOT range [buf, buf+16)
 *            tdata1 = type 6 (mcontrol6), action 0 (breakpoint exception),
 *                     match 1 (NAPOT), s=1, u=1, load=1
 * The load of buf+4 is executed in U-mode; a correct core raises a breakpoint
 * exception (mcause 3) before the load. */
#include "test.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  csrw tselect, zero
  csrr t0, tselect
  bnez t0, fail_setup

  /* Disable trigger while programming tdata2 */
  li t0, (6 << 60)
  csrw tdata1, t0

  la t1, buf
  ori t1, t1, 7
  csrw tdata2, t1

  li t0, (6 << 60) | (1 << 7) | (1 << 4) | (1 << 3) | 1
  csrw tdata1, t0
  csrr t2, tdata1
  srli t3, t2, 60
  li t4, 6
  bne t3, t4, fail_setup       /* mcontrol6 not accepted */
  srli t3, t2, 7
  andi t3, t3, 0xf
  li t4, 1
  bne t3, t4, fail_setup       /* NAPOT match not accepted */

  ENTER_MODE(0, user_code)

fail_setup:
  FAIL(2)

user_code:
  la a1, buf
load_insn:
  lw a2, 4(a1)                 /* inside [buf, buf+16): trigger must fire */
  ecall                        /* reached only if the trigger did not fire */

  .align 2
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  li t5, 3
  beq t6, t5, got_bp
  li t5, 8
  beq t6, t5, no_fire
  FAIL(3)                      /* unexpected trap */
no_fire:
  FAIL(1)                      /* NAPOT trigger did not fire */
got_bp:
  /* Breakpoint must be at the load instruction */
  csrr t0, mepc
  la t1, load_insn
  bne t0, t1, bad_epc
  PASS
bad_epc:
  FAIL(4)

  .section .data
  .align 6
buf:
  .dword 0x1111111111111111
  .dword 0x2222222222222222
  .dword 0x3333333333333333
  .dword 0x4444444444444444
