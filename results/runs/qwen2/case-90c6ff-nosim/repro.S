/* repro.S -- bug reproducer for the CVA6 G-stage (Sv39x4) instruction-fetch
 * canonical-address check.
 *
 * Bug (per TASK.md):
 *   With G-stage translation enabled and VS-stage translation off
 *   (vsatp = Bare), VS-mode cannot execute code at some valid guest-physical
 *   addresses: instruction fetch raises a page fault.  Sv39x4 guest-physical
 *   addresses are 41 bits wide and zero-extended.
 *
 * Root cause (verified in core/cva6_mmu/cva6_mmu.sv, instr_interface):
 *   The canonical-address check always uses the 39-bit Sv39 range:
 *       fetch_vaddr[VLEN-1 : SV-1]   =  fetch_vaddr[63:38]
 *   and faults unless those bits are all-0 or all-1.  When only the G-stage is
 *   active the address being translated is a 41-bit guest-physical address, so
 *   the check should be against the 41-bit zero-extension (bits [63:41] == 0,
 *   i.e. CVA6Cfg.SVX).  Because it uses SV (=39) instead, every valid 41-bit
 *   GPA with bits[40:38] != 000 -- i.e. any GPA in [2^38, 2^41) -- is treated
 *   as non-canonical and raises INSTR_PAGE_FAULT.  A conforming core executes
 *   such code normally.
 *
 * Strategy:
 *   - In M-mode build a G-stage 1 GiB leaf (g_root[1024]) mapping the GPA
 *     region [0x10000000000, +1 GiB) onto the physical DRAM region
 *     [0x80000000, +1 GiB).  Top-level G-stage index of 0x10000000000 is
 *     GPA[40:30] = 1024.
 *   - Enable G-stage (hgatp), keep VS-stage Bare, and make VS-mode traps go to
 *     M-mode (hedeleg = 0).
 *   - mret into VS-mode at the payload, whose PC lies inside that GPA region
 *     (bit 40 set).  The payload then stores the success code to `tohost`
 *     through the G-stage and halts -> PASS on a conforming core.
 *   - On the buggy core the very first VS-mode fetch at that GPA faults, traps
 *     to M-mode, and trap_handler reports FAIL.
 */
#include "test.h"
#include "hyp.h"

  .section .text
  .globl test_main

test_main:
  PMP_ALLOW_ALL

  /* G-stage: map GPA [0x10000000000, +1 GiB) -> physical [0x80000000, +1 GiB).
   * Top-level index = 0x10000000000 >> 30 = 1024. */
  GIGA_LEAF(g_root, 1024, 0x80000000, G_RWX)
  HGATP_ON

  /* Undeliver VS-mode exceptions to S-mode so they are taken to M-mode, where
   * our trap_handler lives. */
  csrw hedeleg, zero

  /* t0 = payload's GPA = payload_phys + (0x10000000000 - 0x80000000). */
  la   t0, payload
  li   t1, 0xff80000000               /* 0x10000000000 - 0x80000000 */
  add  t0, t0, t1

  /* mret into VS-mode: MPP = S, MPV = 1, mepc = payload GPA. */
  li   t1, (3 << 11)
  csrc mstatus, t1                    /* MPP = 0 */
  li   t1, (1 << 11)
  csrs mstatus, t1                    /* MPP = S */
  li   t1, MSTATUS_MPV
  csrs mstatus, t1                    /* MPV = 1 */
  csrw mepc, t0
  mret

/* ---- VS-mode payload; PC is a 41-bit GPA in the mapped region (bit 40 set) ---- */
payload:
  /* Store the success code to `tohost` through the G-stage. */
  li   a0, 1
  la   t0, tohost
  li   t1, 0xff80000000               /* physical -> GPA offset */
  add  t0, t0, t1                     /* t0 = tohost's GPA */
  sd   a0, 0(t0)
payload_halt:
  j    payload_halt

/* Any trap (the spurious VS-mode fetch fault on the buggy core) -> FAIL. */
  .globl trap_handler
  .align 2
trap_handler:
  csrr a0, mcause
  slli a0, a0, 1
  ori  a0, a0, 1
  j    _halt

HYP_TABLES
