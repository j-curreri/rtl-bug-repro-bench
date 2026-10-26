#include "test.h"

/* Reproducer: a store whose Sv39 page-table walk hits a PMP-denied page must raise a
 * store/AMO access fault (cause 7). The buggy core reports a load access fault (cause 5)
 * when the hypervisor extension is present. */

  .section .data
  .align 12
root_pt: .space 4096          /* Sv39 root table; its PMP entry denies all S/U access */

  .section .text
  .globl test_main
test_main:
  /* PMP entry 0: NAPOT 4 KiB around root_pt, no permissions (denies S/U access).
   * PMP entry 1: NAPOT over all memory, RWX (allows everything else). */
  la t0, root_pt
  srli t0, t0, 2
  ori t0, t0, 0x1ff
  csrw pmpaddr0, t0
  li t0, -1
  csrw pmpaddr1, t0
  li t0, ((0x1f << 8) | 0x18)
  csrw pmpcfg0, t0

  /* satp = Sv39 with root_pt */
  la t0, root_pt
  srli t0, t0, 12
  li t1, (8 << 60)
  or t0, t0, t1
  csrw satp, t0
  sfence.vma

  /* Make M-mode loads/stores use S-mode translation (MPRV=1, MPP=S). */
  li t0, (3 << 11)
  csrc mstatus, t0
  li t0, (1 << 11)
  csrs mstatus, t0
  li t0, (1 << 17)
  csrs mstatus, t0

  /* Store to a VA whose first-level PTE lives in the denied page. */
  li t1, 0x40000000
  li t2, 0x1234
  sd t2, 0(t1)

  /* No trap: the store should not have succeeded. */
  FAIL(2)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 7                    /* store/AMO access fault */
  bne t0, t1, 1f
  PASS
1:
  FAIL(1)
