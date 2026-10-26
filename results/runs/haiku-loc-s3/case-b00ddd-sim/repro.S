#include "hyp.h"

/* CVXIF FU sets x_exception.gva = v_i for an illegal instruction. The tval of an
 * illegal-instruction trap holds instruction bits, not a guest virtual address, so
 * the spec requires mstatus.GVA = 0 after the trap, while mstatus.MPV = 1 (came from VS). */

  .globl test_main
test_main:
  PMP_ALLOW_ALL
  ENTER_VS(vs_code)

vs_code:
  .word 0x0000000b          # custom-0: offloaded to CVXIF and rejected -> illegal in VS-mode
  FAIL(1)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 2                  # ILLEGAL_INSTR
  bne t0, t1, bad
  csrr t0, mstatus
  srli t0, t0, 38
  andi t0, t0, 3            # bit 0: GVA, bit 1: MPV
  li t1, 2                  # expect GVA=0, MPV=1
  bne t0, t1, bad
  PASS
bad:
  FAIL(7)
