# ---------------------------------------------------------------------------
# repro.S - bare-metal reproducer for a CVA6 Sdtrig bug
#
# Bug: mcontrol6 address-match triggers configured with match=1 (NAPOT) never
# fire for accesses inside the configured naturally aligned power-of-two
# range.  The NAPOT comparison helper (napot_match64/32 in triggers_pkg.sv)
# rejects every tdata2 encoding whose value is not of the form 2^k - 1, i.e.
# every real (non zero-base) NAPOT range.  Exact-match triggers (match=0)
# work, so the trigger machinery itself is fine - only the NAPOT comparison
# is broken.
#
# Program:
#   1. configure trigger 0 as an mcontrol6 load-address trigger with
#      match=1 (NAPOT) over an 8-byte window in .data, action=0
#      (breakpoint exception), M-mode privilege bit set;
#   2. perform one load inside that window.
#
# On a spec-correct core the load raises a breakpoint exception (mcause = 3).
# The trap handler disables the trigger, returns past the load and sets the
# `s1` flag -> main sees the flag and ends with PASS.
#
# On the buggy core the NAPOT match silently fails, no trap occurs, the load
# simply completes and control falls through to the FAIL path.  Any other
# (unexpected) trap fails as well.
#
# Config proves the needed features exist (see
# core/include/cv64a6_imafdc_sv39_sdtrig_config_pkg.sv):
#   SdtrigMcontrol6          = 1
#   SdtrigMcontrol6LoadAddr  = 1
#   SdtrigNrTriggers         = 4
#   SdtrigSupportedActions   = 6'b000101 -> action 0 (breakpoint) supported
#   SdtrigSupportedMatch     = 6'b11     -> match 0 (equal) and 1 (NAPOT)
# ---------------------------------------------------------------------------

  # Harness macros and contract (PASS / FAIL(n), test_main, M-mode): test.h.
  # Keeping every instruction exactly 4 bytes lets the trap handler skip the
  # trapping load with a fixed "mepc += 4".
  #include "test.h"
  .section .text
  .option norvc
  .align 2

  .globl test_main
test_main:
  # ---------------- prepare -------------------------------------------------
  li    s1, 0                        # s1 = 0: "trigger has not fired" yet

  # Warm the scratch line up in the write-through d-cache *before* the trigger
  # is armed, so that the trigger-target load itself sees a short, well
  # defined access (and no extra trap-free miss work around it).
  la    t0, scratch
  lw    t1, 0(t0)                    # warm-up load - trigger still off

  # ---------------- configure trigger 0 --------------------------------------
  # tselect = 0
  li    t1, 0
  csrw  tselect, t1

  # tdata2: NAPOT encoding of an 8-byte naturally aligned window that starts
  # at &scratch: tdata2 = base | (size/2 - 1) = &scratch | 0b11.
  # scratch is 8-byte aligned, so this covers [&scratch, &scratch + 8).
  li    t3, 3
  or    t0, t0, t3
  csrw  tdata2, t0

  # tdata1 = 0x60000000000000c1: mcontrol6 (type = 6) with
  #   [21]      select  = 0   -> compare on ADDRESS, not data
  #   [18:16]   size    = 0   -> any access size
  #   [15:12]   action  = 0   -> breakpoint exception (mcause = 3)
  #   [10:7]    match   = 1   -> NAPOT match against tdata2
  #   [6]       m       = 1   -> armed in M-mode
  #   [2:0]     e/s/l   = 001 -> fires on loads only
  li    t3, 0x60000000000000c1
  csrw  tdata1, t3

  # ---------------- the load that must fire the trigger -----------------------
  # Spec-correct behaviour: NAPOT range in tdata2 contains &scratch, so this
  # load matches trigger 0 and raises a breakpoint exception (mcause = 3).
  # Buggy behaviour: the NAPOT comparison never succeeds, so no exception
  # occurs and execution just continues with the next instruction.
  lw    t2, 0(t0)                    # expected breakpoint on a correct core

  # Reached directly (buggy core: no trap) or via the trap handler, which
  # returned one instruction past the load (correct core).
  bnez  s1, 2f                       # handler set s1=1 -> trigger fired
  FAIL(1)                            # fell through: NAPOT trigger never fired
2:                                   # -> buggy core
  # Trigger fired correctly -> what we came here to prove.
  PASS                               # -> correct core

# ---------------------------------------------------------------------------
# Trap handler.  The only expected trap is the breakpoint exception (mcause 3)
# raised by trigger 0 on the load inside the NAPOT window.
# ---------------------------------------------------------------------------
  .globl trap_handler
  .align 2
trap_handler:
  csrr  t3, mcause
  li    t6, 3                        # BREAKPOINT
  bne   t3, t6, 1f
  # Our trigger fired. First make sure it cannot fire again: rewrite tdata1
  # as mcontrol6 with every enable bit cleared (privilege bits all 0 means
  # nothing can ever match it again).
  li    t0, 0
  csrw  tselect, t0
  li    t0, 0x6000000000000000       # type 6, load/store/execute/m/s/u = 0
  csrw  tdata1, t0
  # Skip the trapping load and report success back to test_main.
  csrr  t3, mepc
  addi  t3, t3, 4
  csrw  mepc, t3
  li    s1, 1                        # tell main the trigger fired
  mret
1:
  FAIL(2)                            # unexpected trap -> fail

# ---------------------------------------------------------------------------
# Data: one 8-byte aligned scratch window, the trigger's NAPOT range.
# The window overlaps nothing else the program touches: the only access to it
# is the warm-up load (before the trigger exists) and the trigger-target load.
# ---------------------------------------------------------------------------
  .section .data
  .align 3
  .globl scratch
scratch:
  .space 16