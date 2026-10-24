#include "test.h"

/* Bug: for some synchronous exceptions the trap CSRs are not written as the
 * privileged spec requires. Concretely, a LOAD PAGE FAULT does not record the
 * faulting virtual address in mtval.
 *
 * We enable Sv39, map only the 1 GiB region holding our code/data
 * ([0x80000000, 0xBFFFFFFF)), then perform a load from the unmapped virtual
 * address 0x1000. This raises a load page fault (mcause = 13). Per the spec,
 * mepc holds the PC of the faulting load and mtval holds the faulting virtual
 * address (0x1000).
 *
 * A correct core: mcause=13, mepc=PC(load), mtval=0x1000  -> PASS
 * Buggy core:     mtval is not the faulting virtual address  -> FAIL(3)
 *
 * FAIL codes: 1=mcause, 2=mepc, 3=mtval, 7=trap not taken. */
  .data
  .align 12
ptable: .space 4096
  .text

  .globl test_main
test_main:
  .align 2
  la   t0, handler
  csrw mtvec, t0
  /* PTE[2] = 1 GiB superpage @ phys 0x80000000 (identity map of our region).
   * PTE value = (0x80000000 >> 12) << 10 | (V|R|W|X|A|D) = 0x20000000 | 0x3F. */
  la   t0, ptable
  addi t0, t0, 16
  li   t1, 0x2000003F
  sd   t1, 0(t0)
  /* satp = Sv39 (mode 8) | ppn = ptable >> 12 */
  la   t0, ptable
  srli t0, t0, 12
  li   t1, 8
  slli t1, t1, 60
  or   t0, t0, t1
  csrw satp, t0
  fence i, i
  /* Trigger the load page fault: 0x1000 lies in top-level entry 0, which is
   * unmapped, so the access is a load page fault with tval = 0x1000. */
  li   t2, 0x1000
trigld:
  .align 2
  ld   t1, 0(t2)
  /* If we get here the load did not trap: the bug let it complete. */
  li   a0, 7
  j    _halt

  .align 2
handler:
  csrr t0, mcause
  csrr t1, mepc
  csrr t2, mtval
  li   t3, 13
  bne  t0, t3, f_cause
  la   t3, trigld
  bne  t1, t3, f_epc
  li   t3, 0x1000
  bne  t2, t3, f_tval
  PASS
f_cause:
  FAIL(1)
f_epc:
  FAIL(2)
f_tval:
  FAIL(3)
