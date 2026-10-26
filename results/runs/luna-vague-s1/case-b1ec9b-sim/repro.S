#include "test.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Return from M to S with MIE=0, MPIE=1, and MPRV=1.  MRET must
     restore MIE from MPIE, set MPIE, clear MPP to U, and clear MPRV. */
  csrr t0, mstatus
  li t1, ((3 << 11) | (1 << 7) | (1 << 3) | (1 << 17))
  not t1, t1
  and t0, t0, t1
  li t1, ((1 << 11) | (1 << 7) | (1 << 17))
  or t0, t0, t1
  csrw mstatus, t0
  la t0, s_check
  csrw mepc, t0
  mret

s_check:
  /* Trap back to M so the handler can inspect the state MRET left behind. */
  ecall

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 9                  /* Environment call from S-mode. */
  bne t0, t1, failed_2
  csrr t0, mstatus
  /* Trap entry must have captured the S-mode privilege in MPP. */
  li t1, (3 << 11)
  and t0, t0, t1
  li t1, (1 << 11)
  bne t0, t1, failed_3
  csrr t0, mstatus
  /* MRET restored MIE=1, so trap entry copied it to MPIE.  MRET to S
     must also have cleared MPRV; trap entry leaves MPRV unchanged. */
  andi t1, t0, (1 << 7)
  li t2, (1 << 7)
  bne t1, t2, failed_4
  li t2, (1 << 17)
  and t1, t0, t2
  bnez t1, failed_5

  /* Exercise another MRET with MPP=M.  MIE is restored, MPIE is set,
     MPP becomes U, and MPRV is preserved for this M-mode return. */
  csrr t0, mstatus
  li t1, ((3 << 11) | (1 << 7) | (1 << 3) | (1 << 17))
  not t1, t1
  and t0, t0, t1
  li t1, ((3 << 11) | (1 << 7) | (1 << 17))
  or t0, t0, t1
  csrw mstatus, t0
  la t0, m_check
  csrw mepc, t0
  mret

m_check:
  csrr t0, mstatus
  li t1, ((1 << 3) | (1 << 7) | (3 << 11) | (1 << 17))
  and t0, t0, t1
  /* MPP=M returns to M; MPRV is unchanged. */
  li t1, ((1 << 3) | (1 << 7) | (1 << 17))
  bne t0, t1, failed_6
  PASS

failed_2:
  FAIL(1)
failed_3:
  FAIL(2)
failed_4:
  FAIL(3)
failed_5:
  FAIL(4)
failed_6:
  FAIL(5)
