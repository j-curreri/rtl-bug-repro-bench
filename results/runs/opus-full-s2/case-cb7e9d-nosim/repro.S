/* Sdtrig mcontrol6 NAPOT (match=1) address triggers must fire for any access
 * inside the naturally aligned range. A NAPOT range around `buf` is
 * configured for loads and stores in S-mode; accesses at non-base offsets in its lower half must
 * raise breakpoint exceptions (mcause 3). */
#include "test.h"

  .option norvc
  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  li s0, 0                      /* breakpoint count */
  la s1, buf

  /* trigger 0: NAPOT load+store, S-mode, action=breakpoint */
  csrw tselect, zero
  csrw tdata1, zero
  addi t0, s1, 31               /* low 5 bits set: 64-byte range per spec */
  csrw tdata2, t0
  li t0, (6 << 60) >> 32
  slli t0, t0, 32
  ori t0, t0, (1 << 7) | (1 << 4) | (1 << 1) | (1 << 0)
  csrw tdata1, t0
  csrr t1, tdata1
  srli t1, t1, 60
  li t2, 6
  bne t1, t2, fail_cfg

  ENTER_MODE(1, smode)

smode:
  ld a1, 24(s1)                 /* must trap: inside range */
  sd a1, 8(s1)                  /* must trap: inside range */
  lw a1, 16(s1)                 /* must trap: inside range */
  ecall

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 3
  beq t0, t1, on_bp
  li t1, 9
  bne t0, t1, bad_trap
  /* ecall from S: check all three accesses hit */
  li t1, 3
  bne s0, t1, fail_cnt
  PASS
on_bp:
  addi s0, s0, 1
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret
bad_trap:
  FAIL(3)
fail_cnt:
  FAIL(2)
fail_cfg:
  FAIL(1)

  .data
  .align 6
buf: .zero 128
