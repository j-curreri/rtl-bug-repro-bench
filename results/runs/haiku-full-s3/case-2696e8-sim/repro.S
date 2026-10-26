#include "hyp.h"

/* Bug: after an HLVX read hits an execute-only G-stage page (filling the DTLB), a plain
 * HLV read of the same page succeeds. Correct behaviour: HLV raises a load guest-page
 * fault (cause 21), since only HLVX may treat execute permission as read permission. */

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  # G-stage: guest-physical 0x80000000 (1 GiB leaf 2) -> physical 0x80000000, execute-only.
  GIGA_LEAF(g_root, 2, 0x80000000, PTE_V | PTE_X | PTE_U | PTE_A | PTE_D)
  HGATP_ON

  # Seed the probe value through an untranslated M-mode store.
  la t0, probe
  li t1, 0x1234
  sd t1, 0(t0)

  # Step 1: HLVX may read through an execute-only page; it must succeed and return the seed.
  la a1, probe
  hlvx.hu a2, (a1)
  li t1, 0x1234
  bne a2, t1, 1f
  # Step 2: plain HLV of the same page must fault. A trap is routed to trap_handler (PASS).
  hlv.hu a2, (a1)
  # Reached only if HLV completed without a fault: the bug is present.
  FAIL(3)
1:
  FAIL(1)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 21                 # load guest-page fault
  bne t0, t1, 2f
  PASS
2:
  FAIL(2)

  .section .data
  .align 3
probe: .dword 0

HYP_TABLES
