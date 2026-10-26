#include "test.h"
#include "hyp.h"

  .globl test_main
test_main:
  PMP_ALLOW_ALL

  // DRAM at 0x80000000 is gigapage 2
  // Identity-map 1 GiB DRAM in G-stage with G_RWX
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)

  // Identity-map 1 GiB DRAM in VS-stage with VS_RWX
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)

  // Map gigapage 1 (VA 0x40000000) in VS-stage with GPA bit 41 set (reserved PPN bits).
  // In Sv39x4, a guest physical address is 41 bits (bits 40:0).
  // In a VS-stage PTE, bit 39 corresponds to bit 29 of PPN (bit 41 of GPA).
  la t0, vs_root
  li t1, (1 * 8)
  add t0, t0, t1
  li t1, 1
  slli t1, t1, 39
  ori t1, t1, VS_RWX
  sd t1, 0(t0)

  // Map gigapage 1 in G-stage with G_RWX so G-stage has no translation fault
  GIGA_LEAF(g_root, 1, 0x40000000, G_RWX)

  HGATP_ON

  la t2, vs_root
  VSATP_ON(t2)

  ENTER_VS(vs_code)

vs_code:
  // Access VA 0x40000000 in VS-mode
  li t1, 0x40000000
  lw t0, 0(t1)

  // If no trap occurred, fail
  FAIL(1)

  .globl trap_handler
  .align 2
trap_handler:
  // In M-mode, check mcause.
  // According to the RISC-V Privileged / Hypervisor specification (Section 5.5),
  // a VS-stage leaf PTE with reserved PPN bits non-zero must raise a
  // first-stage page-fault exception (cause 13: LOAD_PAGE_FAULT).
  // On this buggy core, cause 21 (LOAD_GUEST_PAGE_FAULT) is erroneously reported.
  csrr t0, mcause
  li t1, 13
  bne t0, t1, 1f
  PASS

1:
  FAIL(2)

HYP_TABLES
