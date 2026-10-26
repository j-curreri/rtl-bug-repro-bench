#include "hyp.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Identity-map the 1 GiB DRAM region through both translation stages. */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)

  /* These writes must take effect before entering virtual supervisor mode. */
  la t0, g_root
  srli t0, t0, 12
  li t1, SATP_SV39
  or t0, t0, t1
  /* hgatp[59:58] are reserved above this implementation's 14-bit VMID. */
  li t1, 0x0c00000000000000
  or t0, t0, t1
  csrw hgatp, t0
  hfence.gvma
  csrr t0, hgatp
  srli t0, t0, 58
  andi t0, t0, 3
  bnez t0, bad_hgatp
  csrw satp, zero

  /*
   * In VS-mode, the architectural SATP address (0x180) aliases VSATP.
   * Start with VSATP=Bare, then write Sv39 through SATP and check the
   * hypervisor-visible VSATP value after the guest ecall.
   */
  ENTER_VS(guest_start)

guest_start:
  la t0, vs_root
  srli t0, t0, 12
  li t1, SATP_SV39
  or t0, t0, t1
  csrw satp, t0
  ecall

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 10                  /* Environment call from VS-mode. */
  bne t0, t1, unexpected_trap
  csrr t0, vsatp
  la t1, vs_root
  srli t1, t1, 12
  li t2, SATP_SV39
  or t1, t1, t2
  bne t0, t1, bad_vsatp
  PASS
bad_vsatp:
  FAIL(2)
bad_hgatp:
  FAIL(3)
unexpected_trap:
  FAIL(127)

HYP_TABLES
