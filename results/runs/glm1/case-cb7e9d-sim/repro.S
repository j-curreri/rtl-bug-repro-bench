/* repro.S - NAPOT (mcontrol6) address-match trigger bug reproducer.
 *
 * Bug (core/include/triggers_pkg.sv): napot_match32()/napot_match64() first run
 *   is_valid_napot = ((base & (base + 1)) == 0)
 * and refuse to match unless tdata2 is a pure ones-run starting at bit 0.  For
 * any real region (e.g. tdata2 = 0x80003023) that check fails, so NAPOT
 * triggers never fire for the accesses inside the configured naturally
 * aligned range.  Exact match (match=0) skips the validity check and works.
 *
 * Program (M-mode), one trap per test, state machine via the "phase" word:
 *   1. arm trigger 0: mcontrol6, select=0 (address), match=1 (NAPOT), m=1,
 *      action=0 (breakpoint), execute=1, tdata2 = exec_slot | 0x3
 *      -> fetch the instruction at exec_slot inside the NAPOT range:
 *         a spec-correct core raises breakpoint (mcause 3) before it runs;
 *         this core raises nothing
 *   2. arm trigger 1: same but store=1, tdata2 = store_buf | 0x3
 *      -> sd to store_buf: breakpoint again on a correct core
 *
 * tdata2 = B | 0x3 with a 16-byte aligned B encodes the naturally aligned
 * range starting at B under either NAPOT size convention, so the exec slot
 * (4 instructions at B) and the store at B stay inside the configured range.
 * tdata1 layout (trigger_module.sv RV64 write path): [63:60]=type 6,
 * [21]=select, [15:12]=action, [10:7]=match, [6]=m, [2]=execute, [1]=store.
 */

#include "test.h"

#define MC6_EXEC_TV   0x60000000000000C4   /* type=6, m=1, match=1(NAPOT), execute=1, action=0 */
#define MC6_STORE_TV  0x60000000000000C2   /* type=6, m=1, match=1(NAPOT), store=1, action=0 */

  .text
  .globl test_main
  .globl trap_handler

test_main:
  /* ---- arm trigger 0: NAPOT execute-address trigger over the 16-byte
   *      aligned slot at .L_texec ---- */
  li   t0, 0
  csrw tselect, t0
  la   t1, .L_texec
  ori  t1, t1, 0x3
  csrw tdata2, t1
  li   t1, MC6_EXEC_TV
  csrw tdata1, t1

  .align 4                          /* 16-byte aligned NAPOT slot */
.L_texec:                           /* mepc on trap = .L_texec */
  nop
  nop
  nop
  nop
.L_resume_exec:
  j    .L_check1                    /* buggy core falls out of the slot untrapped */

.L_check1:
  lw   t0, phase
  beqz t0, .L_fail3                 /* no breakpoint for NAPOT execute -> bug */

  /* ---- arm trigger 1: NAPOT store-address trigger over
   *      [store_buf, store_buf+3] ---- */
  li   t0, 1
  csrw tselect, t0
  la   t1, store_buf
  ori  t1, t1, 0x3
  csrw tdata2, t1
  li   t1, MC6_STORE_TV
  csrw tdata1, t1

  la   a2, store_buf
.L_tstore:                          /* mepc on trap = address of the sd */
  sd   t2, 0(a2)

.L_resume_store:
  j    .L_check2

.L_check2:
  lw   t0, phase
  li   t1, 2
  bne  t0, t1, .L_fail4             /* no breakpoint for NAPOT store -> bug */

  PASS                              /* both NAPOT triggers fired as specified */

.L_fail3:
  FAIL(3)
.L_fail4:
  FAIL(4)

/* Trap handler.  Expected:
 *   phase 0 -> breakpoint from the NAPOT execute trigger at .L_texec -> phase = 1
 *   phase 1 -> breakpoint from the NAPOT store  trigger at .L_tstore -> phase = 2
 * Anything else (wrong mcause, wrong mepc, extra trap) is unexpected -> FAIL(9).
 * Disarms every trigger (write type 15 into tdata1 bits [63:60]) so the
 * handler itself cannot be re-trapped, then resumes right after the
 * faulting instruction. */
  .align 2
trap_handler:
  csrr t6, mcause
  li   t5, 3                        /* BREAKPOINT */
  bne  t6, t5, .L_unexpected

  lw   t5, phase
  beqz t5, .L_from_exec
  li   t4, 1
  beq  t5, t4, .L_from_store
  j    .L_unexpected

.L_from_exec:
  la   t4, .L_texec
  csrr t5, mepc
  bne  t5, t4, .L_unexpected
  li   a1, 1                        /* next phase */
  j    .L_trap_common

.L_from_store:
  la   t4, .L_tstore
  csrr t5, mepc
  bne  t5, t4, .L_unexpected
  li   a1, 2                        /* fall through */

.L_trap_common:
  /* disarm all triggers */
  li   t0, 0
.L_disarm:
  csrw tselect, t0
  li   t1, 0xF000000000000000
  csrw tdata1, t1
  addi t0, t0, 1
  li   t2, 4
  blt  t0, t2, .L_disarm

  /* resume at the label right after the faulting instruction */
  la   t0, .L_resume_exec
  li   t1, 1
  beq  a1, t1, 1f
  la   t0, .L_resume_store
1:
  csrw mepc, t0

  /* advance the phase */
  la   t0, phase
  sw   a1, 0(t0)
  mret

.L_unexpected:
  FAIL(9)

  .data
  .align 2
  .globl phase
phase:
  .word 0                           /* 0 = waiting exec trap, 1 = waiting store trap, 2 = done */
  .align 4
  .globl store_buf
store_buf:
  .space 16                         /* NAPOT region for the store trigger */