/* Reproducing a two-stage-translation exception-cause bug.
 *
 * Bug: in VS-mode with two-stage translation, a load whose VS-stage walk reaches a
 * NON-LEAF PTE whose PPN points outside the guest-physical address space (i.e.
 * pte.ppn[PPNW-1:GPPNW] != 0, here bits [43:29]) is reported with the wrong
 * exception cause. The spec requires a guest-page fault
 * (LOAD_GUEST_PAGE_FAULT = 21). The buggy core mis-classifies it as a plain
 * load page fault (LOAD_PAGE_FAULT = 13).
 *
 * This test:
 *   - sets up a G-stage (hgatp) that identity-maps the 1 GiB region starting at
 *     DRAM (0x80000000), and a VS-stage (vsatp) whose top-level (level-0) PTE is
 *     a non-leaf PTE with PPN = 1<<29 (=> GPA base 2^41, just outside the 41-bit
 *     guest-physical space);
 *   - enters V/S mode and performs a load through that virtual address;
 *   - the load must trap. A conforming core traps with cause 21; the buggy core
 *     traps with cause 13.
 *
 * The delegation CSRs reset to 0, so the trap is delivered to M-mode (mtvec) and
 * the code is read from mcause. PASS only when mcause == 21.
 */
#include "test.h"
#include "hyp.h"

  HYP_TABLES

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* G-stage root: 16 KiB table. Index 2 covers GPA [0x80000000, 0xC0000000).
   * Make it a 1 GiB leaf with HPA base 0x80000000  =>  identity mapping.
   * PTE = (0x80000000 >> 12) << 10 | G_RWX = 0x200000FF. */
  RAW_PTE(g_root, 2, 0x200000FF)

  /* VS-stage root: 4 KiB table.
   * In V/S mode the instruction fetches ALSO use the VS-stage, so the top-level
   * PTE covering the code (GVA 0x80002xxx => index 2) must be a valid 1 GiB
   * identity leaf. PTE = (0x80000000>>12)<<10 | G_RWX = 0x200000FF. */
  RAW_PTE(vs_root, 2, 0x200000FF)

  /* Top-level PTE at index 0 (GVA 0x2000) is a non-leaf PTE whose PPN = 1<<29
   * points to a GPA (base 2^41) outside the 41-bit guest-physical space.
   * v=1, r=0, x=0, a=d=u=0 => valid non-leaf pointer, out of range.
   * PTE = (1<<29) << 10 | PTE_V = 0x8000000001. */
  RAW_PTE(vs_root, 0, 0x8000000001)

  /* Enable G-stage then VS-stage translation. */
  HGATP_ON
  la t0, vs_root
  VSATP_ON(t0)

  /* Enter V/S mode. */
  ENTER_VS(vs_body)

/* ------------------- V/S mode ------------------- */
vs_body:
  li t5, 0x2000
  lw t0, 0(t5)      /* two-stage load; must trap (VS PTE is out of range) */
  /* Reaching here means the load did not fault: wrong on any conforming core. */
  FAIL(202)

/* ------------------- M-mode trap handler ------------------- */
  .align 2
  .globl trap_handler
trap_handler:
  csrr t6, mcause          /* capture the cause */
  /* mret back to M-mode: clear MPV, set MPP=M. */
  li t0, MSTATUS_MPV
  csrc mstatus, t0
  li t0, (3 << 11)
  csrs mstatus, t0
  la t0, m_check
  csrw mepc, t0
  mret

m_check:
  li t1, 21                /* LOAD_GUEST_PAGE_FAULT */
  bne t6, t1, fail_cause   /* a conforming core reports cause 21 here */
  PASS
fail_cause:
  FAIL(201)
