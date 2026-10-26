#include "test.h"

/* Repro: an mcontrol6 execute trigger with match=NAPOT (1) on an S-mode
 * instruction must fire when the instruction lies inside the naturally aligned
 * 8-byte region encoded by tdata2 = target | 3. napot_match64 in
 * triggers_pkg.sv rejects any base that has high address bits set, so the
 * trigger never fires and the program falls through to the ecall. */

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  csrw 0x7a0, zero              /* tselect = 0 */
  la t0, s_target
  ori t0, t0, 3                 /* NAPOT encoding, bit 2 is 0 since target is 8-aligned */
  csrw 0x7a2, t0                /* tdata2 */
  li t1, 0x6000000000000094     /* type=6, execute, s=1, match=NAPOT(1), action=0 */
  csrw 0x7a1, t1                /* tdata1 */
  ENTER_MODE(1, s_target)

  .balign 8
s_target:
  nop
  nop
  ecall                         /* reached only if the trigger did not fire */

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 3                      /* breakpoint exception from the trigger */
  bne t0, t1, 1f
  la t2, s_target
  csrr t3, mepc
  bne t3, t2, 1f
  PASS
1:
  FAIL(1)
