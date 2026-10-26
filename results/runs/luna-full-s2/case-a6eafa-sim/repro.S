#include "hyp.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* The VS root is physically in DRAM, but will be addressed through the
   * GPA window [0x40000000, 0x80000000), which is G-stage execute-only. */
  GIGA_LEAF(g_root, 1, 0x80000000, (PTE_V | PTE_X | PTE_A | PTE_D))
  /* HLVX's target guest page is in a separate, executable GPA window. */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)

  /* A level-2 VS leaf maps VA 0 to GPA 0x80000000 as execute-only. */
  RAW_PTE(vs_root, 0, 0x20000049)

  HGATP_ON

  /* Physical vs_root is in the 0x80000000-mapped window. Convert its
   * physical address to the aliased GPA used by the first G-stage leaf. */
  la t0, vs_root
  li t1, 0x40000000
  sub t0, t0, t1
  VSATP_ON(t0)

  /* HLVX is a hypervisor load, so run in HS with SPVP selecting VS/S mode. */
  li t0, HSTATUS_SPVP
  csrs hstatus, t0
  ENTER_MODE(1, try_hlvx)

try_hlvx:
  li t0, 0
  hlvx.hu t1, (t0)
  /* Reaching here means the execute-only PTE page was incorrectly readable. */
  FAIL(1)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 21                    /* load guest-page fault */
  beq t0, t1, expected_fault
  FAIL(2)
expected_fault:
  PASS

  HYP_TABLES
