#include "hyp.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  la t0, trap_handler
  csrw mtvec, t0
  /* MPP = M, MPV = 1 */
  li t0, (3 << 11)
  csrs mstatus, t0
  li t0, MSTATUS_MPV
  csrs mstatus, t0
  la t0, after_mret
  csrw mepc, t0
  mret
after_mret:
  /* Still in M-mode, V must be 0. Clear MPV just in case, then trap. */
  li t0, MSTATUS_MPV
  csrc mstatus, t0
  li s1, 0
  ecall
  /* s1 = 1 means handler saw MPV=0 (V was 0 at trap) */
  li t0, 1
  bne s1, t0, fail
  PASS
fail:
  FAIL(1)

  .align 4
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 11          /* ecall from M-mode */
  bne t0, t1, bad_trap
  csrr t0, mstatus
  li t1, MSTATUS_MPV
  and t0, t0, t1
  bnez t0, mpv_set
  li s1, 1
  j ret_trap
mpv_set:
  li s1, 2
ret_trap:
  /* return to M-mode with MPV=0 */
  li t0, MSTATUS_MPV
  csrc mstatus, t0
  li t0, (3 << 11)
  csrs mstatus, t0
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret
bad_trap:
  FAIL(3)
