/* Sdtrig mcontrol6 NAPOT (match=1) load-address trigger must fire.
 * tdata2 = base | 0x7 describes a 16-byte NAPOT range around `buf`.
 * A U-mode load inside that range must raise a breakpoint (mcause 3)
 * before the load executes. */
#include "test.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  csrw satp, zero

  csrw tselect, zero
  csrr t0, tselect
  bnez t0, fail_setup

  /* type=6 (mcontrol6), action=0, match=1 (NAPOT), u=1, load=1 */
  li t0, (6 << 60) | (1 << 7) | (1 << 3) | 1
  csrw tdata1, t0
  la t1, buf
  ori t1, t1, 0x7
  csrw tdata2, t1

  la t2, buf
  addi t2, t2, 8
  ENTER_MODE(0, user_code)

user_code:
  ld a1, 0(t2)            /* inside NAPOT range: must trap with breakpoint */
trig_pc:
  ecall                   /* reached only if the trigger did not fire */

fail_setup:
  FAIL(4)

  .globl trap_handler
  .align 4
trap_handler:
  csrr t0, mcause
  li t1, 3
  beq t0, t1, got_bp
  li t1, 8
  beq t0, t1, no_fire
  FAIL(3)
no_fire:
  FAIL(1)
got_bp:
  csrr t0, mepc
  la t1, user_code
  bne t0, t1, bad_epc
  PASS
bad_epc:
  FAIL(2)

  .section .data
  .align 4
buf:
  .dword 0x1111, 0x2222
