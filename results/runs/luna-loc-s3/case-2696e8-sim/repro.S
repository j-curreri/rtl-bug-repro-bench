#include "hyp.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  li t0, (1 << 3)
  csrc mstatus, t0              /* keep asynchronous interrupts out of the test */

  /* GPA 0 is the guest code window, backed by DRAM and RWX. */
  GIGA_LEAF(g_root, 0, 0x80000000, G_RWX)
  /* GPA 0x80000000 is the data window, backed by DRAM but execute-only. */
  GIGA_LEAF(g_root, 2, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A))

  /* VA 0x80000000 -> GPA 0 (guest code); VA 0xC0000000 -> GPA 0x80000000. */
  GIGA_LEAF(vs_root, 2, 0, VS_RWX)
  GIGA_LEAF(vs_root, 3, 0x80000000, VS_RWX)

  HGATP_ON
  la t0, vs_root
  VSATP_ON(t0)

  /* MXR initially allows loads from the execute-only G-stage leaf. */
  li t0, (1 << 19)
  csrs mstatus, t0
  ENTER_VS(guest_start)

  /* Should only be reached if the expected guest-page fault did not occur. */
  FAIL(1)

  .align 2
guest_start:
  /* This miss succeeds with MXR=1 and installs the G-stage translation. */
  li t0, 0xC0000000
  ld t1, 0(t0)

  /* Ask M-mode to clear MXR, then retry the same cached translation. */
  ecall
  .globl guest_second
guest_second:
  li t0, 0xC0000000
  ld t1, 0(t0)
  j guest_second

  .align 2
  .globl trap_handler
trap_handler:
  la t0, trap_seen
  ld t1, 0(t0)
  beqz t1, first_ecall
  csrr t0, mcause
  li t1, 21
  beq t0, t1, expected_fault
  andi a0, t0, 255
  slli a0, a0, 1
  ori a0, a0, 1
  j _halt

first_ecall:
  li t1, 1
  sd t1, 0(t0)
  li t0, (1 << 19)
  csrc mstatus, t0
  /* Return to an M-mode trampoline before re-entering VS-mode. */
  li t0, ((3 << 11) | MSTATUS_MPV)
  csrc mstatus, t0
  li t0, (3 << 11)
  csrs mstatus, t0
  la t0, resume_in_m
  csrw mepc, t0
  mret

resume_in_m:
  li t0, (3 << 11)
  csrc mstatus, t0
  li t0, ((1 << 11) | MSTATUS_MPV)
  csrs mstatus, t0
  la t0, guest_second
  csrw mepc, t0
  mret

expected_fault:
  PASS

  .data
  .align 3
trap_seen: .dword 0

HYP_TABLES
