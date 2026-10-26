#include "test.h"
#include "hyp.h"

  .globl test_main
  .globl trap_handler

test_main:
  # Allow full memory access in lower privilege modes
  PMP_ALLOW_ALL

  # Transition from M-mode into VS-mode at vs_entry
  ENTER_VS(vs_entry)

  # Should not be reached
  FAIL(6)

  .align 2
vs_entry:
  # Execute an illegal instruction in VS-mode
  .word 0x00000000

  # Should not be reached if the illegal instruction trapped
  FAIL(5)

  .align 2
trap_handler:
  # Verify exception cause is illegal instruction (cause 2)
  csrr t0, mcause
  li t1, 2
  bne t0, t1, fail_cause

  # Verify faulting PC is vs_entry
  la t1, vs_entry
  csrr t0, mepc
  bne t0, t1, fail_mepc

  # Read mstatus to inspect virtualization and trap state
  csrr t0, mstatus

  # Verify MPV (bit 39): previous virtualization mode must be VS-mode (1)
  srli t1, t0, 39
  andi t1, t1, 1
  beqz t1, fail_not_vs

  # Check GVA (bit 38):
  # According to the RISC-V Hypervisor specification, mstatus.GVA must be 0
  # for illegal instruction exceptions because mtval does not hold a guest virtual address.
  # On the buggy CVA6 core with CV-X-IF enabled, mstatus.GVA is erroneously set to 1.
  srli t1, t0, 38
  andi t1, t1, 1
  bnez t1, fail_gva

  # PASS on a correct RISC-V core
  PASS

fail_gva:
  FAIL(1)

fail_cause:
  FAIL(2)

fail_mepc:
  FAIL(3)

fail_not_vs:
  FAIL(4)
