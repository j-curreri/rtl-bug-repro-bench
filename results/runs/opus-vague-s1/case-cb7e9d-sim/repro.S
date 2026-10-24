/* Sdtrig mcontrol6 address-match reproducer.
 * Each check arms trigger 0 in M-mode, then runs one access in S-mode.
 * A correct core takes a breakpoint (mcause 3) on that access. */
#include "test.h"

#define MC6        (6 << 60)
#define MC6_S      (1 << 4)
#define MC6_EXEC   (1 << 2)
#define MC6_STORE  (1 << 1)
#define MATCH_EQ   (0 << 7)
#define MATCH_NAPOT (1 << 7)

  .option norvc

/* Arm trigger 0 with tdata1 = cfg, tdata2 = addr, run `body` in S-mode,
 * then expect exactly one breakpoint; otherwise FAIL(n). */
#define CHECK(n, cfg, addr, body)       \
  csrw tselect, zero;                   \
  csrw tdata1, zero;                    \
  la t0, addr;                          \
  csrw tdata2, t0;                      \
  li t0, (cfg);                         \
  csrw tdata1, t0;                      \
  li s11, 0;                            \
  la s10, 9f;                           \
  ENTER_MODE(1, body);                  \
9:                                      \
  csrw tdata1, zero;                    \
  li t0, 1;                             \
  bne s11, t0, fail_##n

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  csrw satp, zero

  /* sanity: equal match on execute and store (these fire on this core) */
  CHECK(1, MC6|MC6_S|MC6_EXEC|MATCH_EQ, x_tgt, x_body)
  CHECK(2, MC6|MC6_S|MC6_STORE|MATCH_EQ, data, s_body)

  /* NAPOT: tdata2 = data | 3 covers an 8-byte range starting at data
   * (spec: M = XLEN-1 - index of lowest 0 bit), so an access at the base
   * must fire. The buggy core only accepts NAPOT values of the form 2^k-1. */

  CHECK(3, MC6|MC6_S|MC6_STORE|MATCH_NAPOT, data_n3, s_body)
  CHECK(4, MC6|MC6_S|MC6_EXEC|MATCH_NAPOT, x_tgt_n3, x_body)
  PASS

fail_1: FAIL(1)
fail_2: FAIL(2)
fail_3: FAIL(3)
fail_4: FAIL(4)

/* S-mode bodies; each ends with ecall back to M-mode. */
  .align 4
x_body:
  nop
  .align 3
x_tgt:
  nop
  ecall

s_body:
  la t1, data
  sd zero, 0(t1)
  ecall

  .align 2
  .globl trap_handler
trap_handler:
  csrr t5, mcause
  li t6, 3
  beq t5, t6, 1f
  li t6, 9                  /* ecall from S: resume M-mode at s10 */
  bne t5, t6, 2f
  li t6, (3 << 11)
  csrs mstatus, t6
  csrw mepc, s10
  mret
1:                          /* breakpoint: count it, disarm, skip insn */
  addi s11, s11, 1
  csrw tdata1, zero
  csrr t6, mepc
  addi t6, t6, 4
  csrw mepc, t6
  mret
2:
  csrr t6, mcause
  FAIL(127)

  .data
  .align 4
data:     .dword 0
          .dword 0
  .equ data_n3, data + 3
  .equ x_tgt_n3, x_tgt + 3
