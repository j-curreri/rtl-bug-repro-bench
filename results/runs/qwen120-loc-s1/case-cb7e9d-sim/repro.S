#include "test.h"

/*
 * Reproduce the Sdtrig mcontrol6 NAPOT bug in core/include/triggers_pkg.sv.
 *
 * napot_match32()/napot_match64() start with:
 *
 *     is_valid_napot = ((base & (base + 1)) == 0);
 *     if (!is_valid_napot) return 0;
 *
 * For a NAPOT encoding of a region that lives in DRAM (base >= 0x8000_0000)
 * the expression (base & (base+1)) keeps the high address bits set, so it is
 * non-zero, is_valid_napot == 0 and the function returns 0 unconditionally.
 * The mcontrol6 trigger therefore NEVER fires for any real (DRAM) address,
 * even though a spec-conforming NAPOT match must match the full
 * [base, base+size-1] region at that address.
 *
 * Test (M-mode):
 *   1. Configure trigger 0 as an mcontrol6 STORE trigger with NAPOT address
 *      match on a 16-byte region in DRAM  (tdata2 = base + size/2 - 1).
 *   2. Perform a store to an address inside that region.
 *
 *   - correct core : the store address matches the NAPOT region -> the store
 *                    trigger fires -> breakpoint exception -> PASS.
 *   - buggy core   : napot_match64() returns 0 for every address -> no
 *                    trigger -> the store commits and we fall through -> FAIL.
 */

  .section .text
  .globl test_main
  .align 2
test_main:
  # --- trigger 0: mcontrol6, store, NAPOT address match, M-mode, breakpoint ---
  li   t0, 0
  csrw 0x7a0, t0                 # tselect = 0

  # tdata1 (XLEN=64, mcontrol6):
  #   [63:60]=6 (mcontrol6)  [6]=m  [1]=store
  #   [10:7] =1 (match = napot)  [15:12]=0 (action = breakpoint)
  li   t1, 0x60000000000000C2
  csrw 0x7a1, t1                 # tdata1

  # tdata2 = region base + size/2 - 1   (size = 16  ->  base + 7)
  la   t2, REGION
  addi t2, t2, 7
  csrw 0x7a2, t2                 # tdata2

  # Store to the middle of the 16-byte region (base + 8): unambiguously inside
  # the full [base, base+15] region, so a correct core must match it.
  addi t3, t2, 1                # t3 = base + 8
  li   t4, 0xA5
  sb   t4, 0(t3)                # store @ base+8 -> fires on a correct core

  # If we reach here the trigger did not fire -> buggy core.
  FAIL(1)

  # The only breakpoint source in this program is the mcontrol6 store trigger.
  # Strong global definition overrides the harness' .weak trap_handler so that
  # _start (which does `csrw mtvec, trap_handler`) points here.
  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, 0x342                # mcause
  li   t1, 3                    # BREAKPOINT
  bne  t0, t1, trap_fail
  PASS
trap_fail:
  FAIL(2)

  .section .data
  .align 4
REGION:
  .space 16
