#include "hyp.h"

.globl test_main
test_main:
  PMP_ALLOW_ALL
  ENTER_VS(vs_code)

.align 2
vs_code:
  .word 0x00000000 // unimp: illegal instruction in VS-mode

.globl trap_handler
.align 2
trap_handler:
  // 1. mcause must be ILLEGAL_INSTR (2)
  csrr t0, mcause
  li t1, 2
  bne t0, t1, fail_cause

  // 2. mstatus.MPV (bit 39) must be 1 (trapped from virtualized mode)
  csrr t0, mstatus
  li t1, 1
  slli t1, t1, 39
  and t2, t0, t1
  beqz t2, fail_mpv

  // 3. mstatus.MPP (bits 12:11) must be 1 (S-mode)
  csrr t0, mstatus
  li t1, (3 << 11)
  and t2, t0, t1
  li t1, (1 << 11)
  bne t2, t1, fail_mpp

  // 4. mstatus.GVA (bit 38) must be 0
  // Illegal instruction exceptions are not caused by guest virtual addresses,
  // so mstatus.GVA must be 0 according to the RISC-V hypervisor specification.
  // The buggy core incorrectly sets mstatus.GVA to 1.
  csrr t0, mstatus
  li t1, 1
  slli t1, t1, 38
  and t2, t0, t1
  bnez t2, fail_gva

  // 5. mtval2 must be 0 for traps other than guest-page faults
  csrr t0, mtval2
  bnez t0, fail_mtval2

  // 6. mtinst must be 0 when no transformed instruction is defined
  csrr t0, mtinst
  bnez t0, fail_mtinst

  PASS

fail_cause:
  FAIL(1)
fail_mpv:
  FAIL(2)
fail_mpp:
  FAIL(3)
fail_gva:
  FAIL(4)
fail_mtval2:
  FAIL(5)
fail_mtinst:
  FAIL(6)
