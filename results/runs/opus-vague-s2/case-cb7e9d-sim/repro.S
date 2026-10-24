/* Sdtrig mcontrol6 NAPOT (match=1) address triggers never fire.
 *
 * triggers_pkg::napot_match64 rejects any tdata2 unless it is of the form
 * 0..01..1 ((base & (base+1)) == 0), so a NAPOT range such as
 * tdata2 = 0x80010003 (bytes 0x80010000-0x80010007) is treated as invalid
 * and never matches. Per the Sdtrig spec the trigger must fire.
 *
 * Each case arms trigger 0 (U-mode, action=breakpoint), runs an access in
 * U-mode, and counts breakpoint exceptions (mcause 3) in s1.
 *   case 1: store-address equal match (sanity, works on both cores)
 *   case 2: store-address NAPOT match, store at the base of the range
 *   case 3: execute-address NAPOT match on the first instruction of the range
 */
#include "test.h"
  .option norvc
  .text

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 8                  /* ecall from U: back to M-mode continuation */
  beq t0, t1, 1f
  li t1, 3                  /* breakpoint from trigger */
  bne t0, t1, 2f
  addi s1, s1, 1
  csrw tdata1, zero         /* disarm so the access can proceed */
  csrr t0, mepc
  addi t0, t0, 4            /* skip the triggering instruction */
  csrw mepc, t0
  mret
1: jr s2
2: FAIL(100)

#define MC6(match, bits) ((6 << 60) | ((match) << 7) | (1 << 3) | (bits))

/* Arm trigger 0 with tdata2 = a2, run `ulab` in U-mode, FAIL(n) unless one hit. */
#define CASE(n, t1val, ulab)    \
  li s1, 0;                     \
  la s2, 9f;                    \
  csrw tselect, zero;           \
  csrw tdata1, zero;            \
  csrw tdata2, a2;              \
  li t0, t1val;                 \
  csrw tdata1, t0;              \
  ENTER_MODE(0, ulab);          \
9:                              \
  csrw tdata1, zero;            \
  li t0, 1;                     \
  beq s1, t0, 8f;               \
  FAIL(n);                      \
8:

  .globl test_main
test_main:
  PMP_ALLOW_ALL

  li a2, 0x80010000
  CASE(1, MC6(0, 2), u_store)

  li a2, 0x80010003         /* NAPOT: 0x80010000..0x80010007 */
  CASE(2, MC6(1, 2), u_store)

  la a2, u_x1
  ori a2, a2, 1             /* NAPOT: u_x1..u_x1+3 */
  CASE(3, MC6(1, 4), u_exec)

  PASS

  .align 4
u_store:
  li t0, 0x80010000
  sd t1, 0(t0)
  ecall

  .align 4
u_exec:
  nop
  nop
u_x1:
  nop
  nop
  ecall
