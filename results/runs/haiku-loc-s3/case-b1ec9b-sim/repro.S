#include "test.h"

/* Spec: when xRET changes to a privilege mode less privileged than M, MPRV is set to 0.
 * Set MPRV=1 in M-mode, mret to S-mode, take an ecall back to M-mode and check MPRV. */
  .section .text
  .globl test_main
test_main:
  la t0, my_trap  # install here: crt.S's default trap_handler stays in mtvec otherwise
  csrw mtvec, t0
  PMP_ALLOW_ALL
  li t0, (1 << 17)  # mstatus.MPRV
  csrs mstatus, t0
  ENTER_MODE(1, s_code)

s_code:
  ecall
  FAIL(2)

  .align 2
my_trap:
  csrr t0, mstatus
  li t1, (1 << 17)
  and t0, t0, t1
  bnez t0, mprv_still_set
  PASS

mprv_still_set:
  FAIL(1)
