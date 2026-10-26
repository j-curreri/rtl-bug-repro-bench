#include "hyp.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* GPA 0x80000000 holds this code and the page tables. */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  /* Put the test data in a separate G-stage giga page, mapped to DRAM. */
  GIGA_LEAF(g_root, 3, 0x80000000, G_RWX)
  la t0, probe_data
  li t1, 0x13579bdf
  sw t1, 0(t0)
  la t0, fault_seen
  sd zero, 0(t0)

  HGATP_ON
  ENTER_VS(guest_start)

guest_start:
  /* Warm the combined translation for this GPA. */
  li t0, 0xc0004000
  lw t1, 0(t0)
  li t2, 0x13579bdf
  bne t1, t2, fail_data

  /* Ask M-mode to invalidate this G-stage mapping and fence its GPA. */
  ecall

  /* This must fault after the G-stage leaf has been invalidated. */
  li t0, 0xc0004000
  lw t1, 0(t0)

guest_after_fault:
  la t0, fault_seen
  ld t0, 0(t0)
  li t1, 1
  bne t0, t1, fail_no_fault
  PASS

fail_data:
  FAIL(1)
fail_no_fault:
  FAIL(2)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 10                 /* Environment call from VS-mode */
  beq t0, t1, do_fence
  li t1, 21                 /* Load guest-page fault */
  beq t0, t1, note_fault
  FAIL(3)

do_fence:
  /* Remove the G-stage leaf covering the probe GPA (root slot 3). */
  la t2, g_root
  sd zero, 24(t2)
  li t0, 0xc0004000
  hfence.gvma t0, x0
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret

note_fault:
  la t2, fault_seen
  li t1, 1
  sd t1, 0(t2)
  /* Skip the faulting load and return to VS-mode. */
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret

  .section .data
  .align 12
probe_data:
  .dword 0
fault_seen:
  .dword 0

HYP_TABLES
