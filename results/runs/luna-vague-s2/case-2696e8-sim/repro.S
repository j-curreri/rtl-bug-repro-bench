#include "hyp.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* GPA [0, 1 GiB) contains the test code and the VS page table. */
  GIGA_LEAF(g_root, 0, 0x80000000, G_RWX)
  /* GPA [1 GiB, 2 GiB) maps the test data but is execute-only. */
  GIGA_LEAF(g_root, 1, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A | PTE_D))
  /* GVA 0 maps to GPA 1 GiB, readable at the VS stage. */
  GIGA_LEAF(vs_root, 0, 0x40000000, VS_RWX)

  HGATP_ON

  /* VSATP holds a guest physical address, so convert the table's PA to GPA. */
  la t0, vs_root
  li t1, 0x80000000
  sub t0, t0, t1
  srli t0, t0, 12
  li t1, SATP_SV39
  or t0, t0, t1
  csrw vsatp, t0
  hfence.vvma

  /* Permit the expected guest-page fault to enter the HS trap vector. */
  li t0, (1 << 21)
  csrs medeleg, t0

  /* Enter HS (S-mode); VMXR must not grant read access at G-stage. */
  li t0, ((1 << 19) | (1 << 8))
  csrs hstatus, t0
  ENTER_MODE(1, hs_main)

  .align 2
hs_main:
  la t0, hs_trap
  csrw stvec, t0
  li a0, 0
  /* Prime the translation with a load that is allowed by execute permission. */
  hlvx.wu t0, (a0)
  /* Ordinary HLV must still enforce read permission on the cached G-stage page. */
  hlv.w t0, (a0)
  /* The load returned, so G-stage read permission was not enforced. */
  FAIL(1)

  .align 2
hs_trap:
  csrr t0, scause
  li t1, 21                  /* load guest-page fault */
  beq t0, t1, 1f
  FAIL(2)
1:
  PASS

  HYP_TABLES
