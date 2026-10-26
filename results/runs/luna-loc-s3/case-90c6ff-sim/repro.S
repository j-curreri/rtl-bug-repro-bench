#include "hyp.h"

/*
 * A VS-stage translation is still scoped by VMID when hgatp is Bare.  The
 * TLB must not let two guests with the same VS ASID and VA alias merely
 * because no G-stage translation is active.
 */

  .section .text
  .align 2
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Build two VS Sv39 page-table trees.  Both map VA 0x4000, but to
   * different physical pages. */
  la t0, vs_root1
  la t1, vs_l1_1
  srli t1, t1, 12
  slli t1, t1, 10
  ori t1, t1, 1
  sd t1, 0(t0)
  la t0, vs_l1_1
  la t1, page_a
  srli t1, t1, 12
  slli t1, t1, 10
  ori t1, t1, 0xcf
  sd t1, 0(t0)                  /* 2 MiB leaf at VA 0 */
  /* Map the guest code's 0x80000000 region with a 1 GiB identity leaf. */
  la t0, vs_root1
  li t1, 0x200000cf
  sd t1, 16(t0)                 /* root VPN2 = 2, PPN = 0x80000 */

  la t0, vs_root2
  la t1, vs_l1_2
  srli t1, t1, 12
  slli t1, t1, 10
  ori t1, t1, 1
  sd t1, 0(t0)
  la t0, vs_l1_2
  la t1, page_b
  srli t1, t1, 12
  slli t1, t1, 10
  ori t1, t1, 0xcf
  sd t1, 0(t0)
  la t0, vs_root2
  li t1, 0x200000cf
  sd t1, 16(t0)

  /* VMID 1, hgatp Bare.  Bare G-stage does not remove VMID from the
   * context of a VS-stage translation. */
  li t0, (1 << 44)
  csrw hgatp, t0
  la t0, vs_root1
  srli t0, t0, 12
  li t1, SATP_SV39
  or t0, t0, t1
  csrw vsatp, t0
  sfence.vma
  hfence.gvma
  hfence.vvma
  ENTER_VS(guest1)

guest1:
  li t0, 0
  ld s0, 0(t0)
  ecall

guest2:
  li t0, 0
  ld s0, 0(t0)
  ecall

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 10                     /* ECALL from VS-mode */
  bne t0, t1, unexpected_trap
  csrr t0, mepc
  la t1, guest1
  beq t0, t1, first_guest_done

  /* Second guest must have seen page_b. */
  li t0, 0x22222222
  bne s0, t0, fail_alias
  PASS

first_guest_done:
  li t0, 0x11111111
  bne s0, t0, fail_first

  /* Change only VMID and VSATP.  There is intentionally no fence here:
   * distinct VMIDs must select distinct cached translation contexts. */
  li t0, (2 << 44)
  csrw hgatp, t0
  la t0, vs_root2
  srli t0, t0, 12
  li t1, SATP_SV39
  or t0, t0, t1
  csrw vsatp, t0
  la t0, guest2
  csrw mepc, t0
  mret

fail_first:
  FAIL(1)
fail_alias:
  FAIL(2)
unexpected_trap:
  FAIL(3)

  .section .bss
  .align 12
vs_root1: .space 4096
  .align 12
vs_l1_1:  .space 4096
  .align 12
vs_root2: .space 4096
  .align 12
vs_l1_2:  .space 4096

  .section .data
  .align 21
page_a:   .dword 0x11111111
  .space 0x1ffff8
page_b:   .dword 0x22222222
