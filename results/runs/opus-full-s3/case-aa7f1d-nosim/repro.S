#include "hyp.h"

/* MRET with MPP=M and MPV=1 must return to M-mode with V=0 (MPV ignored).
 * Observe V via CSR remapping (sscratch -> vsscratch when V=1) and via the
 * MPV value saved by a subsequent M-mode trap (must be 0). */

  .text
  .globl test_main
test_main:
  li t0, 0x1111
  csrw sscratch, t0
  li t0, 0x2222
  csrw vsscratch, t0

  /* MPP = M, MPV = 1 */
  li t0, (3 << 11)
  csrs mstatus, t0
  li t0, MSTATUS_MPV
  csrs mstatus, t0
  la t0, after_mret
  csrw mepc, t0
  mret

after_mret:
  /* still M-mode with V=0: sscratch must be the real sscratch */
  csrr t2, sscratch
  li t1, 0x1111
  bne t2, t1, fail1
  /* MPV must have been cleared by mret */
  csrr t2, mstatus
  li t1, MSTATUS_MPV
  and t2, t2, t1
  bnez t2, fail2
  /* trap from M-mode: mcause = 11 and MPV saved as 0 */
  li s1, 0
  ecall
  li t1, 1
  bne s1, t1, fail3
  PASS

fail1: FAIL(1)
fail2: FAIL(2)
fail3: FAIL(3)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  li t1, 11
  bne t6, t1, fail4
  csrr t2, mstatus
  li t1, MSTATUS_MPV
  and t2, t2, t1
  bnez t2, fail5
  li t1, (3 << 11)
  csrr t2, mstatus
  and t2, t2, t1
  bne t2, t1, fail6
  li s1, 1
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret
fail4: FAIL(4)
fail5: FAIL(5)
fail6: FAIL(6)
