/* Bug reproducer: two-stage translation, VS-stage walk reaches a non-leaf PTE
 * pointing outside the guest-physical address space.
 *
 * Configuration used here (cv64a6_imafdch_sv39):
 *   GPLEN = 41, GPPNW = 29  ->  a guest physical address has 41 bits; a PTE PPN
 *   with any of bits [43:29] set points outside the guest-physical space.
 *
 * Scenario: VS-mode, Sv39 (vsatp) + Sv39x4 (hgatp) two-stage translation.
 *   A load from VA 0x4000_0000 has vpn2 = 1. The VS-stage walk reaches the
 *   top-level PTE vs_root[1], which is a *valid non-leaf* PTE (V=1, R=W=X=0,
 *   A=D=U=0, no reserved bits) whose PPN has bit 29 set, i.e. the next-level
 *   VS-stage table lives at GPA 2^41 + 4 KiB, outside the guest-physical
 *   address space. The G-stage translation of that table address must fault,
 *   so the spec requires a LOAD GUEST-PAGE FAULT (cause 21 in this core's
 *   encoding). The buggy core instead reports an ordinary LOAD PAGE FAULT
 *   (cause 13).
 *
 *   correct core: mcause = 21  -> PASS
 *   buggy core  : mcause = 13  -> FAIL(5)
 */
#include "test.h"
#include "hyp.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* G-stage table (Sv39x4 root, 16 KiB, 1 GiB leaves only):
   *   index 0: identity map of GPA [0, 1 GiB)
   *   index 2: identity map of GPA [2, 3 GiB), covering code, tables, tohost */
  GIGA_LEAF(g_root, 0, 0x00000000, G_RWX)
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)

  /* VS-stage table (Sv39 root, 4 KiB):
   *   index 2: 1 GiB leaf, identity-maps VA [2, 3 GiB) -> our code/tables
   *   index 1: the bad non-leaf PTE: V=1 | PPN bit 0 | PPN bit 29 (raw PTE
   *            bits 10 and 39). R=W=X=0 so it is a table pointer, and no
   *            A/D/U bits so the walk classifies it as the out-of-range-GPA
   *            case rather than a bad-PTE case. */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  RAW_PTE(vs_root, 1, 0x8000000401)

  /* enable two-stage translation for VS-mode */
  HGATP_ON
  la t0, vs_root
  VSATP_ON(t0)

  /* mret into VS-mode (V=1, S-mode) */
  ENTER_VS(vs_body)

vs_body:
  /* In VS-mode with two-stage translation.
   * VA 0x40000000 has vpn2 = 1, so the VS-stage walk reaches vs_root[1],
   * the non-leaf PTE pointing outside the guest-physical address space.
   * The load must trap with a load guest-page fault. */
  li    a0, 0x40000000
  auipc t0, 0
  addi  t0, t0, 4        /* t0 = PC of the load below */
  ld    a0, 0(a0)        /* traps here on both cores */

  /* if we get here the out-of-range table pointer was accepted: wrong */
  FAIL(4)

  .data
  HYP_TABLES

  /* M-mode trap handler: none of the page-fault causes is delegated
   * (medeleg/hedeleg = 0), so the VS-mode trap lands here in M-mode and
   * mcause holds the exception code. */
  .text
  .align 2
  .globl trap_handler
trap_handler:
  csrr  a0, mcause
  csrr  a1, mepc
  andi  a0, a0, 0x3ff    /* keep the exception code field only */
  bne   a1, t0, bad_trap /* trap must come from the load above */
  li    a1, 21           /* LOAD_GUEST_PAGE_FAULT */
  bne   a0, a1, bad_trap
  PASS
bad_trap:
  FAIL(5)
