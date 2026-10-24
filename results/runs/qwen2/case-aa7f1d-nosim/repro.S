/*
 * Bug: MRET with mstatus.MPP == M and mstatus.MPV set.
 *
 * Per the RISC-V H-extension, MRET returns to the privilege mode selected by
 * mstatus.MPP.  When MPP selects M-mode the hart enters M-mode with the
 * virtualization state V = 0 and mstatus.MPV is ignored.  A buggy core instead
 * unconditionally sets V from MPV (csr_regfile.sv: `v_d = mstatus_q.mpv` in the
 * MRET block), leaving the hart in the inconsistent state (privilege = M,
 * virtualization V = 1).
 *
 * How this is observed: when V = 1 the hart redirects S-mode CSR accesses to
 * their virtual (HS) counterparts.  So after MRET-ing into M-mode with MPV set,
 * a read of the S-mode CSR `sscratch` returns the *physical* sscratch on a
 * conforming core (V = 0) but the *virtual* vsscratch on the buggy core (V = 1).
 * We program the two registers with different values and compare the readback.
 *
 *   - conforming core: readback == physical sscratch (1)   -> PASS
 *   - buggy core:      readback == virtual  vsscratch (0)  -> FAIL(2)
 */
#include "test.h"

  .globl test_main
test_main:
  PMP_ALLOW_ALL

  # Mark the *physical* S-mode sscratch with a known value, and make sure the
  # *virtual* vsscratch holds a different one.  M-mode (V = 0) can address both
  # registers directly.
  li    t0, 1
  csrw  sscratch, t0          # physical sscratch := 1
  li    t0, 0
  csrw  vsscratch, t0         # virtual  vsscratch := 0

  # MRET back into M-mode while mstatus.MPV is set.
  #   MPP := 0b11 (M)   -> mstatus bits [12:11]
  #   MPV := 1          -> mstatus bit  39
  li    t0, 0x1800
  csrc  mstatus, t0           # MPP := 00 (U)
  csrs  mstatus, t0           # MPP := 11 (M)
  li    t0, 0x0000008000000000  # 1 << 39
  csrs  mstatus, t0           # MPV := 1
  la    t0, after_mret
  csrw  mepc, t0
  mret

after_mret:
  # A conforming core is here in M-mode with V = 0, so reading the S-mode
  # sscratch returns the physical value (1).  If the hart was (incorrectly)
  # left virtualized (V = 1), the S-mode access is redirected to the virtual
  # vsscratch (0) and the readback diverges from the physical value.
  csrr  t1, sscratch
  li    t2, 1
  bne   t1, t2, fail_virtual
  PASS

fail_virtual:
  FAIL(2)
