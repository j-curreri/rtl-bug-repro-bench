#include "hyp.h"

/* VS-stage root (Sv39) non-leaf PTE for VA 0 points to a valid table, but its PPN has
 * bit 30 set, i.e. the next-table pointer is outside the 41-bit guest-physical space.
 * A load through this entry must raise a guest-page fault (cause 21), not a page fault (13). */
#define LOAD_GUEST_PAGE_FAULT_CAUSE 21

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* G-stage: identity-map the 1 GiB DRAM region at 0x80000000 with a gigapage. */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  HGATP_ON

  /* VS-stage root: identity-map the DRAM gigapage so VS-mode code can be fetched, and
   * make entry 0 a non-leaf (V only) whose PPN has bit 30 set (PTE bit 40). */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  RAW_PTE(vs_root, 0, (1 << 40) | PTE_V)

  /* Enable VS-stage translation; the root table lives at GPA == PA here. */
  la t0, vs_root
  VSATP_ON(t0)

  /* Enter VS-mode and issue a load to VA 0x1000 (VPN2 = 0). */
  ENTER_VS(vs_code)

  .align 2
vs_code:
  li t0, 0x1000
  ld t1, 0(t0)
  /* Reaching here means the load did not fault. */
  FAIL(2)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  li t5, LOAD_GUEST_PAGE_FAULT_CAUSE
  bne t6, t5, 1f
  PASS
1:
  FAIL(1)

HYP_TABLES
