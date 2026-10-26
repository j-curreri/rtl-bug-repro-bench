#include "test.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Return to S with MPIE=1 and MPRV set. MRET must restore MIE and
     clear MPRV when it leaves M-mode. */
  li t0, (3 << 11) | (1 << 7) | (1 << 17)
  csrrc x0, mstatus, t0
  li t0, (1 << 11) | (1 << 7) | (1 << 17)
  csrrs x0, mstatus, t0
  la t0, s_entry
  csrw mepc, t0
  mret

s_entry:
  ecall
  FAIL(1)

u_entry:
  ecall
  FAIL(2)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 8                 /* U-mode ecall */
  beq t0, t1, trap_handler_u_check
  li t1, 9                 /* S-mode ecall */
  bne t0, t1, bad_trap

  csrr t0, mstatus
  li t1, (3 << 11) | (1 << 7) | (1 << 17)
  and t0, t0, t1
  li t1, (1 << 11) | (1 << 7) /* MPP=S, MPIE=1, MPRV=0 */
  bne t0, t1, bad_status

  /* Now return to U with MPIE=0 and MPRV set. MRET must restore MIE=0
     and clear MPRV a second time. */
  li t0, (3 << 11) | (1 << 7) | (1 << 17) | (1 << 3)
  csrrc x0, mstatus, t0
  li t0, (1 << 17)
  csrrs x0, mstatus, t0
  la t0, u_entry
  csrw mepc, t0
  mret

bad_trap:
  FAIL(3)
bad_status:
  FAIL(4)

  /* U-mode ecall: MPP=U, MPIE reflects restored MIE=0, and MPRV is clear. */
trap_handler_u_check:
  csrr t0, mcause
  li t1, 8                 /* U-mode ecall */
  bne t0, t1, bad_trap_u
  csrr t0, mstatus
  li t1, (3 << 11) | (1 << 7) | (1 << 17)
  and t0, t0, t1
  bnez t0, bad_status_u
  PASS
bad_trap_u:
  FAIL(5)
bad_status_u:
  FAIL(6)
