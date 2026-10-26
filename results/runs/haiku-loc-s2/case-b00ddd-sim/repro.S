#include "hyp.h"

/* Bug: cvxif_fu.sv sets x_exception_o.gva = v_i for the illegal-instruction exception that a
 * rejected CVXIF offload raises. A trap whose tval holds an instruction word (not a guest
 * virtual address) must leave GVA clear, so mstatus.GVA must read 0 in the M-mode handler. */

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  ENTER_VS(vs_entry)

vs_entry:
  /* Custom encoding that the example coprocessor does not implement: it rejects the offload,
   * so the core raises an illegal-instruction exception while in VS-mode (V=1). */
  .word 0xffffffff
  FAIL(4)                       /* not reached: the trap must be taken */

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 2                      /* illegal instruction */
  bne t0, t1, bad_cause
  csrr t0, mstatus
  li t1, MSTATUS_GVA
  and t0, t0, t1
  bnez t0, gva_set
  PASS

bad_cause:
  FAIL(5)

gva_set:
  FAIL(6)
