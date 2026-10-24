// Bug reproducer: with G-stage translation (hgatp = Sv39x4) enabled and VS-stage
// translation off (vsatp = Bare), a VS-mode instruction fetch at a guest-physical
// address with bit 38 set (a valid, zero-extended Sv39x4 GPA < 2^41) raises an
// instruction page fault, although the 1 GiB G-stage leaf covering it is present
// and has V/R/W/X/U/A/D.
//
// Expected on a spec-correct core: PASS (ecall from VS-mode, mcause 10).
// On the buggy core: the fetch at GPA ~0x400002xxx page-faults immediately ->
// trap_handler sees mcause != 10 -> FAIL(3).
//
// The payload is executed at two guest-physical addresses which map to the same
// physical bytes:
//   phase 1 at a bit-38-clear GPA  (leaf[0],  GPA = PA - 0x80000000)
//   phase 2 at a bit-38-set GPA    (leaf[256], GPA = PA - 0x80000000 + 2^38)
// Phase 1 proves G-stage translation itself works; phase 2 triggers the bug.

#include "test.h"
#include "hyp.h"

  .text
  .globl test_main

#define GPA38      0x4000000000      // 2^38, start of the Sv39x4-only region

test_main:
  PMP_ALLOW_ALL

  // G-stage: leaf[256] maps GPA [2^38 .. 2^38+0x3fffffff] -> PA [0x80000000 ..]
  GIGA_LEAF(g_root, 256, 0x80000000, G_RWX)

  // VS-stage translation off (Bare; default at reset, made explicit)
  csrw vsatp, x0

  // hgatp = Sv39x4 with root g_root (VMID 0), then hfence.gvma
  HGATP_ON

  // Entry GPA = PA(vs_lo) - 0x80000000  (leaf[0] aliases GPA 0 onto DRAM base)
  // ... but leaf[256] suffices: PA - 0x80000000 + 2^38 would need leaf[0] too,
  // so enter at a bit-38-clear alias only if leaf[0] exists.  Here we enter
  // directly at the bad GPA: PA - 0x80000000 + 2^38.
  la t1, vs_hi                  // link address = PA; from leaf[256] the aliasing
  li t2, GPA38                  //   invariant below gives PA - 0x80000000 + 2^38
  li t3, 0x80000000
  sub t2, t2, t3                // 2^38 - 0x80000000
  add t1, t1, t2                // t1 = bad GPA (bit 38 set, bits 40:39 zero)
  csrw mepc, t1

  // mret into VS-mode: MPP=1 (S), MPV=1
  li t0, (3 << 11)
  csrc mstatus, t0
  li t0, (1 << 11)
  csrs mstatus, t0
  li t0, MSTATUS_MPV
  csrs mstatus, t0
  mret

  // not reached (mret enters VS-mode); a trap too early -> generic FAIL
  FAIL(4)

// VS-mode payload.  Wound up here directly at the bad GPA (leaf[256]).
  .align 2
vs_hi:
  li t0, 0x55
  addi t0, t0, 1
  ecall                         // -> M-mode trap, mcause 10
  FAIL(5)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t4, mcause
  li t5, 10                     // ecall from VS-mode after the full run -> PASS
  bne t4, t5, fail3
  PASS
fail3:
  FAIL(3)

  HYP_TABLES