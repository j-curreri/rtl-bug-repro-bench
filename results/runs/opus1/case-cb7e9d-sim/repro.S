/* Sdtrig mcontrol6 NAPOT address-match reproducer.
 * Trigger 0: exact match (match=0) on buf      -> sanity check, must fire.
 * Trigger 1: NAPOT match (match=1) on buf..+15 -> accesses inside must fire.
 * Both triggers: action=0 (breakpoint exception), U-mode, load+store. */
#include "test.h"

#define MC6_OFF    (6 << 60)
#define MC6_BASE   ((6 << 60) | (1 << 3) | (1 << 1) | (1 << 0))
#define MC6_EQUAL  (MC6_BASE | (0 << 7))
#define MC6_NAPOT  (MC6_BASE | (1 << 7))

  .option norvc
  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  li s1, 0                      /* breakpoint trap counter */
  li s2, 1                      /* current phase */

  /* Phase 1: exact-match trigger 0 on buf. */
  li t0, 0
  csrw tselect, t0
  li t0, MC6_EQUAL
  csrw tdata1, t0
  la t0, buf
  csrw tdata2, t0
  csrr t1, tdata2
  bne t0, t1, fail4
  ENTER_MODE(0, u_phase1)

u_phase1:
  la a1, buf
  sd zero, 0(a1)                /* must trap */
  ecall

after_phase1:
  li t0, 1
  bne s1, t0, fail1

  /* Disable trigger 0 so only the NAPOT trigger can fire in phase 2. */
  li t0, MC6_OFF
  csrw tdata1, t0

  /* Phase 2: NAPOT trigger 1 covering buf..buf+15 (tdata2 = buf | 0x7). */
  li s1, 0
  li s2, 2
  li t0, 1
  csrw tselect, t0
  csrr t1, tselect
  bne t0, t1, fail4
  la t0, buf
  ori t0, t0, 0x7
  csrw tdata2, t0
  li t0, MC6_NAPOT
  csrw tdata1, t0
  ENTER_MODE(0, u_phase2)

u_phase2:
  la a1, buf
  sd zero, 0(a1)                /* inside range: must trap */
  lw a2, 4(a1)                  /* inside range: must trap */
  ld a2, 16(a1)                 /* outside range: no trap */
  ecall

after_phase2:
  li t0, 2
  bne s1, t0, fail2
  li t0, MC6_OFF
  csrw tdata1, t0
  csrw tselect, zero
  csrw tdata1, t0
  PASS
fail1:
  FAIL(1)
fail2:
  FAIL(2)
fail4:
  FAIL(4)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  li t5, 3                      /* breakpoint */
  beq t6, t5, 1f
  li t5, 8                      /* ecall from U */
  bne t6, t5, bad_trap
  li t5, 1
  beq s2, t5, after_phase1
  j after_phase2
1:
  addi s1, s1, 1
  csrr t5, mepc
  addi t5, t5, 4
  csrw mepc, t5
  mret
bad_trap:
  FAIL(3)

  .data
  .align 6
buf:
  .dword 0, 0, 0, 0
