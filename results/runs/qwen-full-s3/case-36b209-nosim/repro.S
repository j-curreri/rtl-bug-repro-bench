#include "test.h"
#include "hyp.h"

/* Reproduce the wrong-exception-cause bug for a VS-stage non-leaf PTE whose
 * PPN points outside the guest-physical-address space.
 *
 * Setup (all in M-mode):
 *   - G-stage (hgatp) root `g_root`: g_root[0] is a top-level leaf mapping the
 *     low GPA region to the physical address of the VS root page table.
 *   - VS-stage (vsatp) root `vs_root`: vs_root[0] is a NON-LEAF PTE (r=w=x=0,
 *     v=1) whose PPN has bit 29 set, i.e. PPN[43:29] != 0, so the PTE points
 *     to a GPA >= 2^41, outside the GPLEN=41 guest-physical address space.
 *   - Enter VS-mode and perform a load. The two-stage walk:
 *       G_INTERMED -> fetch g_root[0] (valid leaf) ->
 *       S_STAGE    -> fetch vs_root[0] (non-leaf, out-of-range PPN) -> fault.
 *
 * The spec requires a *load guest-page fault* (cause LOAD_GUEST_PAGE_FAULT =
 * 21 in this core's riscv_pkg) for this situation. The buggy core mis-reports
 * it as a plain *load page fault* (cause 13).
 *
 * The trap is taken to M-mode (no medeleg/hedeleg), so mcause holds the cause
 * and our M-mode trap_handler can inspect it:
 *   - correct core: mcause == 21 -> PASS
 *   - buggy core:   mcause == 13 -> FAIL
 */

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* g_root[0] = G-stage leaf: ppn = PA(vs_root)>>12, flags = G_RWX.
   * Maps the low GPA region (including GPA 0) to PA(vs_root). */
  la t0, vs_root              /* t0 = PA(vs_root) */
  srli t0, t0, 12             /* t0 = PA(vs_root) >> 12 = ppn */
  slli t0, t0, 10             /* t0 = ppn << 10 */
  li t1, G_RWX
  or t0, t0, t1               /* t0 = G-stage PTE value */
  la t2, g_root
  sd t0, 0(t2)                /* g_root[0] */

  /* vs_root[0] = non-leaf PTE with out-of-range PPN.
   * 0x8000000001: v(bit0)=1, ppn bit29 (PTE bit39)=1 -> PPN=0x20000000,
   * PPN[43:29] != 0 (points to a GPA >= 2^41, outside GPLEN=41).
   * r=w=x=0 => non-leaf.  reserved/n = 0. */
  li t0, 0x8000000001
  la t1, vs_root
  sd t0, 0(t1)                /* vs_root[0] */

  /* Enable the two-stage translation. */
  HGATP_ON                    /* hgatp = Sv39x4 | PA(g_root)>>12 */

  li t3, 0                    /* VS root is at GPA 0 (mapped by g_root[0]) */
  VSATP_ON(t3)                /* vsatp = Sv39 | 0 */

  /* Enter VS-mode; the load below will trap. */
  ENTER_VS(vs_body)

  /* Not reached (the load always traps on both cores). */
  FAIL(3)

vs_body:
  .align 2
  li t0, 0                    /* VA = 0: canonical, VA[38:30]=0 -> vs_root[0] */
  ld t1, 0(t0)                /* two-stage walk hits the out-of-range PTE -> fault */
  /* If we get here the load unexpectedly succeeded: fail. */
  FAIL(4)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 21                   /* riscv::LOAD_GUEST_PAGE_FAULT */
  bne t0, t1, repro_fail
  PASS                        /* correct core: guest-page fault reported */
repro_fail:
  FAIL(5)                     /* buggy core (mcause=13) or any other wrong cause */

  HYP_TABLES
