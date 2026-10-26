#include "test.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* M-mode SRET to S-mode must preserve MPRV. */
  li t0, ((1 << 17) | (1 << 8))  /* MPRV=1, SPP=S */
  csrs mstatus, t0
  la t0, s_start
  csrw sepc, t0
  sret

s_start:
  /* Trap back to M so the handler can inspect the preserved MPRV bit. */
  ecall
  FAIL(1)

  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 9                      /* environment call from S-mode */
  bne t0, t1, fail
  csrr t0, mstatus
  srli t0, t0, 17
  andi t0, t0, 1
  beqz t0, fail
  PASS

fail:
  FAIL(2)
