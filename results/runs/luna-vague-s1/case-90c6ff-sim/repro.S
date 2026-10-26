#include "hyp.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Both GPA regions map into DRAM.  G-stage U=0 is correct for accesses
     made by a VS-mode supervisor guest. */
  GIGA_LEAF(g_root, 2, 0x80000000, (G_RWX & ~PTE_U))
  GIGA_LEAF(g_root, 3, 0x80000000, (G_RWX & ~PTE_U))

  /* Identity-map those guest-physical regions at VS stage. */
  GIGA_LEAF(vs_root, 2, 0x80000000, (VS_RWX))
  GIGA_LEAF(vs_root, 3, 0xc0000000, (VS_RWX))

  la t0, vs_root
  VSATP_ON(t0)
  /* Start with G-stage off so the guest can execute the ecall in the
     initial setup phase.  Its M-mode trap handler enables G-stage. */
  ENTER_VS(guest_setup)

  .align 2
guest_setup:
  ecall

guest_test:
  /* A VS-mode (supervisor) load is permitted by this G-stage leaf with
     U=0.  Region 3 aliases the start of DRAM. */
  li t0, 0xc0000000
  ld t1, 0(t0)
  PASS

  .globl trap_handler
  .align 2
trap_handler:
  la t0, armed
  ld t1, 0(t0)
  bnez t1, unexpected_trap
  li t1, 1
  sd t1, 0(t0)
  HGATP_ON
  la t0, guest_test
  csrw mepc, t0
  mret

unexpected_trap:
  FAIL(127)

  HYP_TABLES
  .align 3
armed: .dword 0
