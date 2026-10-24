#include "hyp.h"

/* Bug: on MRET, the hart's virtualization bit V is taken from mstatus.MPV even
 * when mstatus.MPP selects M-mode, where the H extension says MPV is ignored
 * and V must be 0.  MRET with MPP=M, MPV=1 therefore leaves the buggy core in
 * M-mode with V=1 (an inconsistent virtualization state).
 *
 * V itself is not readable from mstatus, so the test observes it behaviorally:
 *
 *  1. M-mode: set MPP=M, MPV=1 and MRET.
 *       - correct core: M-mode, V=0
 *       - buggy core:   M-mode, V=1
 *  2. M-mode: set MPP=S, MPV=0 and SRET.
 *       - correct core (V=0): HS SRET -> HS (S, V=0)
 *       - buggy core (V=1):   VS SRET -> VU (U, V=1)   [vsstatus.SPP resets to 0]
 *  3. Probe `csrr sstatus`:
 *       - HS (S, V=0): legal -> PASS
 *       - VU (U, V=1): virtual instruction trap -> trap_handler FAILs
 *
 * NOTE (instrumentation, to be cleaned up): until the trap source is known,
 * the handler reports which instruction faulted and with which mcause. */

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* --- step 1: MRET with MPP=M, MPV=1 --- */
  li t0, (3 << 11) | MSTATUS_MPV
  csrc mstatus, t0
  li t0, (3 << 11) | MSTATUS_MPV
  csrs mstatus, t0
  la t0, after_mret
  csrw mepc, t0
  mret

after_mret:
  /* --- step 2: SRET with MPP=S, MPV=0 --- */
  li t0, (3 << 11) | MSTATUS_MPV
  csrc mstatus, t0
  li t0, (1 << 11)
  csrs mstatus, t0
  la t0, probe
  csrw mepc, t0
  sret

probe:
  /* --- step 3: S-mode CSR access: legal in HS, traps from VU --- */
  csrr t0, sstatus
  PASS

  .globl trap_handler
  .align 2
trap_handler:
  /* dump raw mepc (low 12 bits) in the tohost code field */
  csrr t1, mepc
  andi a0, t1, 0xfff
  slli a0, a0, 1
  ori a0, a0, 1
  j _halt
