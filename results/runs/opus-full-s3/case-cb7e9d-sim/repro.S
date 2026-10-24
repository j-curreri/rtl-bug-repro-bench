#include "test.h"

/* mcontrol6: type=6, match=NAPOT(1), s=1, u=1, store=1, action=0 (breakpoint) */
#define MC6_STORE_NAPOT ((6 << 60) | (1 << 7) | (1 << 4) | (1 << 3) | 2)
#define MC6_STORE_EQ    ((6 << 60) | (0 << 7) | (1 << 4) | (1 << 3) | 2)

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  li s0, 0                  /* s0: number of breakpoint traps taken */

  /* Control: exact-match store trigger on buf must fire */
  csrw tselect, zero
  csrw tdata1, zero
  la t0, buf
  csrw tdata2, t0
  li t0, MC6_STORE_EQ
  csrw tdata1, t0
  csrr t1, tdata1
  bne t0, t1, fail_cfg
  la s1, after1
  ENTER_MODE(1, s_store)
after1:
  li t0, 1
  bne s0, t0, fail_eq

  /* NAPOT: tdata2 = buf | 7 describes a naturally aligned range containing buf (buf is 16-byte aligned) */
  csrw tdata1, zero
  la t0, buf
  ori t0, t0, 7
  csrw tdata2, t0
  li t0, MC6_STORE_NAPOT
  csrw tdata1, t0
  csrr t1, tdata1
  bne t0, t1, fail_cfg
  la s1, after2
  ENTER_MODE(1, s_store)
after2:
  li t0, 2
  bne s0, t0, fail_napot
  PASS

fail_cfg:   FAIL(1)
fail_eq:    FAIL(2)
fail_napot: FAIL(3)

/* S-mode: store to buf; then ecall back to M-mode */
s_store:
  la t2, buf
  sd t2, 0(t2)
  ecall

  .align 2
  .globl trap_handler
trap_handler:
  csrr t5, mcause
  li t6, 3                  /* breakpoint */
  beq t5, t6, 1f
  li t6, 9                  /* ecall from S */
  beq t5, t6, 2f
  csrr t6, mcause
  FAIL(127)
1:
  addi s0, s0, 1
  li t6, (6 << 60)
  csrw tdata1, t6           /* disable trigger so the access can complete */
  mret                      /* re-execute the store */
2:
  li t6, (6 << 60)
  csrw tdata1, t6
  li t0, (3 << 11)
  csrs mstatus, t0          /* return to M-mode */
  csrw mepc, s1
  mret

  .data
  .align 4
buf: .dword 0x1122334455667788, 0
