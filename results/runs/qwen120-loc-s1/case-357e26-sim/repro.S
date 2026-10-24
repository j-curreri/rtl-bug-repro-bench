#include "test.h"

/*
 * Bug: PMP NAPOT regions are matched 2x too large.
 *
 * In core/pmp/src/pmp_entry.sv the NAPOT size is computed as
 *
 *     size = trail_ones + 3;      # region = 2^(trail_ones+3) bytes
 *
 * but the RISC-V PMP spec defines a NAPOT entry whose pmpaddr has T
 * trailing-1 bits as a 2^(T+2)-byte region (pmpaddr = (base+size-4)/4,
 * e.g. T=0 -> 4 bytes, T=1 -> 8 bytes).  The extra +1 makes every NAPOT
 * entry cover twice the specified area.
 *
 * Test (observable from S-mode, where PMP is enforced):
 *   - PMP entry 0: NAPOT, deny (R=W=X=0), pmpaddr0 = 0x20000040 (T=0).
 *       correct core: region = [0x80000100, 0x80000104)   (4 bytes)
 *       buggy core  : region = [0x80000100, 0x80000108)   (8 bytes)
 *   - PMP entry 1: NAPOT, RWX, pmpaddr1 = all-1s  -> grants all of DRAM
 *     (identical behaviour on both cores).
 *   - Store a known value at A = 0x80000104 in M-mode (PMP not enforced
 *     there because no entry is locked), then mret to S-mode and load it.
 *       correct core: A is NOT in the 4-byte deny region, entry 1 allows
 *                     the load -> value matches -> PASS.
 *       buggy core  : A IS in the 8-byte deny region; first matching entry
 *                     (the deny entry) is checked first -> PMP load access
 *                     fault -> trap to M-mode -> FAIL.
 */

  .globl test_main
test_main:
  /* ---- M-mode: program PMP ---- */
  li  t0, 0x20000040              /* pmpaddr0 = 0x80000100 >> 2, T=0 */
  csrw pmpaddr0, t0
  li  t0, -1
  csrw pmpaddr1, t0               /* entry 1: allow all of DRAM */
  li  t0, 0x1f18                  /* byte0=0x18 (NAPOT, deny), byte1=0x1f (NAPOT, RWX) */
  csrw pmpcfg0, t0

  /* Known value at the probe address A = 0x80000104 (M-mode, no PMP check) */
  li  t0, 0x12345678
  li  t1, 0x80000104
  sw  t0, 0(t1)

  /* Drop to S-mode where PMP is enforced */
  ENTER_MODE(1, s_mode_test)

  .align 2
s_mode_test:
  /*
   * Load A.  On a spec-conformant core the 4-byte deny region
   * [0x80000100,0x80000104) does not contain A, so the allow-all entry
   * grants the load.  On the buggy core the 8-byte deny region
   * [0x80000100,0x80000108) contains A and denies it -> trap.
   */
  li  t1, 0x80000104
  lw  t0, 0(t1)
  li  t2, 0x12345678
  bne t0, t2, repro_fail
  PASS                            /* reached only on a correct core */

repro_fail:
  FAIL(2)

  /* Any trap (e.g. the PMP load access fault on the buggy core) fails. */
  .globl trap_handler
  .align 2
trap_handler:
  FAIL(1)
