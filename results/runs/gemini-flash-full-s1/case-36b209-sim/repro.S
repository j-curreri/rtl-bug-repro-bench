#include "hyp.h"

  .globl test_main
test_main:
  li s0, 0
  PMP_ALLOW_ALL

  /* Map DRAM 1 GiB (0x80000000) identity in G-stage (GPA 0x80000000 -> PA 0x80000000) */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)

  /* Map DRAM 1 GiB (0x80000000) identity in VS-stage (VA 0x80000000 -> GPA 0x80000000) */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)

  /* In vs_root at index 1 (VA 0x40000000):
   * Write a non-leaf PTE pointing outside the guest-physical address space.
   * For Sv39x4, GPA is 41 bits (GPPN is 29 bits, i.e. PPN[28:0]).
   * PPN bits [43:29] are bits [53:39] of the PTE.
   * Setting bit 39 gives PPN[29] = 1, pointing outside the 41-bit GPA space.
   * Non-leaf PTE has V=1, R=0, W=0, X=0, A=0, D=0, U=0.
   * Reserved bits [62:54] and N-bit (63) are 0.
   */
  la t0, vs_root
  li t1, 1
  slli t1, t1, 39
  ori t1, t1, PTE_V
  sd t1, 8(t0)

  fence rw, rw

  /* Enable G-stage translation */
  HGATP_ON

  /* Enable VS-stage translation */
  la t0, vs_root
  VSATP_ON(t0)

  /* Enter VS-mode at vs_test */
  ENTER_VS(vs_test)

vs_test:
  li s0, 1

  /* In VS-mode, perform a load from VA 0x40000000.
   * The VS-stage walk accesses vs_root[1], encountering the non-leaf PTE
   * pointing outside the guest-physical address space.
   */
  li a1, 0x40000000
  ld t2, 0(a1)

  /* If the load did not trap, fail */
  FAIL(2)

  .globl trap_handler
  .align 2
trap_handler:
  /* If we did not reach the VS-mode load, fail with code 4 */
  li t0, 1
  bne s0, t0, 2f

  /* Check exception cause: spec requires guest-page fault (LOAD_GUEST_PAGE_FAULT = 21).
   * The buggy core erroneously reports LOAD_PAGE_FAULT (13).
   */
  csrr t0, mcause
  li t1, 21
  beq t0, t1, 1f

  /* Wrong cause reported (bug reproduced!) */
  FAIL(3)

1:
  PASS

2:
  FAIL(4)

HYP_TABLES
