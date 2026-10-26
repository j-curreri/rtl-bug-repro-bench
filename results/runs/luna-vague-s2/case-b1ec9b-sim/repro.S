#include "test.h"

  .section .text
  .globl test_main
test_main:
  /* The U-mode ecall below proves that MRET actually changed privilege. */
  li t0, -1
  csrw pmpaddr0, t0
  li t0, 0x1f
  csrw pmpcfg0, t0

  /* MRET to U with MPRV set.  The architecture requires MPRV to be cleared
     when MRET lowers privilege, regardless of whether the H extension exists. */
  li t0, (1 << 7) | (1 << 17)
  csrw mstatus, t0
  la t0, user_code
  csrw mepc, t0
  mret

user_code:
  ecall
  /* An ecall must trap to M-mode; returning here is an error. */
  FAIL(1)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 8                  /* Environment call from U-mode */
  bne t0, t1, bad_trap
  csrr t0, mstatus
  li t1, (1 << 17)
  and t0, t0, t1
  bnez t0, bad_mprv
  PASS

bad_trap:
  FAIL(2)
bad_mprv:
  FAIL(3)
