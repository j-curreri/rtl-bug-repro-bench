/*
 * Reproducer: MRET that returns to S-mode fails to clear mstatus.MPRV.
 *
 * The RISC-V privileged spec requires that MRET clears MPRV when it returns
 * to a privilege level less privileged than M.  In this core the MPRV clear in
 * csr_regfile.sv is gated by `if (CVA6Cfg.RVH)`, and the cv64a6_imafdc_sv39
 * configuration has RVH=0, so MPRV is never cleared on MRET.  The load/store
 * translation/permission logic keys off the same mstatus.MPRV bit, so an M-mode
 * access later observes MPRV still in effect.
 *
 * This program:
 *   1. In M-mode sets MPRV=1 and MPP=S, then MRETs into S-mode.
 *      (A correct core clears MPRV on this MRET; the buggy core does not.)
 *   2. In S-mode executes ecall, which traps back to M-mode (mtvec).
 *   3. In M-mode (trap_handler) reads mstatus.MPRV:
 *        - correct core -> MPRV=0 -> PASS
 *        - buggy core   -> MPRV=1 -> FAIL(2)
 *
 * Any unexpected trap -> FAIL(127).
 */
#include "test.h"

  .section .text
  .globl test_main
  .balign 4

test_main:
  csrci   mstatus, 8          /* clear MIE (bit 3): no M-mode interrupts mid-test */

  PMP_ALLOW_ALL               /* PMP entry 0: RWX for all modes over all memory */

  li      t0, (1 << 17)       /* mstatus.MPRV */
  csrs    mstatus, t0         /* MPRV = 1 */

  ENTER_MODE(1, s_entry)      /* MPP=S; MRET into S-mode (a correct core clears MPRV here) */

s_entry:
  ecall                       /* S-mode ecall -> trap to M-mode, mcause = 9 (ENV_CALL_SMODE) */

  .balign 4
  .globl trap_handler
trap_handler:
  csrr    t0, mcause
  li      t1, 9               /* ENV_CALL_SMODE */
  bne     t0, t1, unexpected  /* any other trap is not what we expect */

  csrr    t0, mstatus
  srli    t0, t0, 17
  andi    t0, t0, 1
  beqz    t0, mprv_cleared    /* MPRV cleared by the MRET -> correct behaviour */

  FAIL(2)                     /* MPRV survived the MRET to S-mode -> the bug */

mprv_cleared:
  PASS

unexpected:
  FAIL(127)
