/*
 * Reproducer: "When an interrupt is taken, some trap CSRs do not hold the
 * values the privileged spec requires."
 *
 * On this core, taking a machine-mode interrupt leaves mtval holding the
 * instruction bits of the interrupted instruction.  The RISC-V Privileged
 * Spec requires mtval = 0 when a trap is taken for an interrupt.
 *
 * The test fires two M-mode interrupts:
 *   test 1: machine software interrupt  (msip via CLINT 0x02000000)
 *   test 2: machine timer interrupt     (mtimecmp 0x02004000, mtime 0x0200BFF8)
 * and verifies the trap CSRs at entry:
 *   mcause  = 2^63 | code
 *   mepc    = PC of the interrupted instruction (inside the poll loop)
 *   mstatus = MIE cleared, MPIE = previous MIE (=1), MPP = M
 *   mtval   = 0
 *
 * Ends with PASS on a spec-compliant core.
 * On the buggy core the mtval check fails: FAIL(6) (test 1) or FAIL(12)
 * (test 2).
 */
#include "test.h"

  .section .bss
  .align 3
flag1: .space 8
flag2: .space 8

  .section .text
  .align 2
  .globl test_main

test_main:
  PMP_ALLOW_ALL
  // quiesce: nothing enabled, nothing pending
  csrw mie, zero
  csrw mstatus, zero
  li t0, 0x02000000
  li t1, 0
  sd t1, 0(t0)            // msip = 0

  // ---------------- test 1: M-mode software interrupt ----------------
  li t0, 0x8
  csrs mie, t0            // mie.MSIP
  li t0, 0x8
  csrs mstatus, t0        // mstatus.MIE
  li t0, 0x02000000
  li t1, 1
  sd t1, 0(t0)            // msip = 1 -> interrupt pending

poll1:
  ld t0, flag1
  beqz t0, poll1
  // loop only exits when the handler ran and set flag1

  // ---------------- test 2: M-mode timer interrupt ----------------
  csrw mie, zero
  csrw mstatus, zero
  li t0, 0x02000000
  li t1, 0
  sd t1, 0(t0)            // msip = 0
  li t0, 0x0200BFF8
  ld t1, 0(t0)            // t1 = mtime
  addi t1, t1, 2047
  addi t1, t1, 2047       // fire ~4094 cycles from now
  li t0, 0x02004000
  sd t1, 0(t0)            // mtimecmp = mtime + 4094
  li t0, 0x80
  csrs mie, t0            // mie.MTIP
  li t0, 0x8
  csrs mstatus, t0        // mstatus.MIE

poll2:
  ld t0, flag2
  beqz t0, poll2
  // loop only exits when the handler ran and set flag2
  PASS

  // ---------------------------------------------------------------
  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 0x8000000000000003
  bne t0, t1, 1f
  j h1
1:
  li t1, 0x8000000000000007
  bne t0, t1, 2f
  j h2
2:
  FAIL(15)

h1:                       // ---- M-mode software interrupt ----
  csrr t0, mepc
  la t1, poll1
  bgeu t0, t1, h1a
  FAIL(1)                 // mepc before the poll loop
h1a:
  la t1, poll1
  addi t1, t1, 16
  bltu t0, t1, h1b
  FAIL(2)                 // mepc past the poll loop
h1b:
  csrr t0, mstatus
  andi t2, t0, 1
  bnez t2, h1c
  j h1d                   // MIE must be cleared
h1c:
  FAIL(3)
h1d:
  andi t2, t0, 0x80
  beqz t2, h1e
  j h1f                   // MPIE must be 1 (MIE was set before the trap)
h1e:
  FAIL(4)
h1f:
  srli t2, t0, 11
  andi t2, t2, 3
  li t3, 3
  bne t2, t3, h1g
  j h1h                   // MPP must be M
h1g:
  FAIL(5)
h1h:
  csrr t0, mtval          // must be 0 for interrupts
  bnez t0, h1i
  j h1done
h1i:
  FAIL(6)
h1done:
  li t0, 0x02000000
  li t1, 0
  sd t1, 0(t0)            // clear msip
  li t1, 0x8
  csrc mie, t1
  csrc mstatus, 1         // MIE = 0 while in the handler (keep MPP = M!)
  la t0, flag1
  li t1, 1
  sd t1, 0(t0)
  mret

h2:                       // ---- M-mode timer interrupt ----
  csrr t0, mepc
  la t1, poll2
  bgeu t0, t1, h2a
  FAIL(7)
h2a:
  la t1, poll2
  addi t1, t1, 16
  bltu t0, t1, h2b
  FAIL(8)
h2b:
  csrr t0, mstatus
  andi t2, t0, 1
  bnez t2, h2c
  j h2d
h2c:
  FAIL(9)
h2d:
  andi t2, t0, 0x80
  beqz t2, h2e
  j h2f
h2e:
  FAIL(10)
h2f:
  srli t2, t0, 11
  andi t2, t2, 3
  li t3, 3
  bne t2, t3, h2g
  j h2h
h2g:
  FAIL(11)
h2h:
  csrr t0, mtval          // must be 0 for interrupts
  bnez t0, h2i
  j h2done
h2i:
  FAIL(12)
h2done:
  li t0, 0x02004000
  li t1, -1
  sd t1, 0(t0)            // mtimecmp = -1 -> no further timer interrupt
  li t1, 0x80
  csrc mie, t1
  csrc mstatus, 1         // MIE = 0 while in the handler (keep MPP = M!)
  la t0, flag2
  li t1, 1
  sd t1, 0(t0)
  mret
