/* Bug reproducer: instruction fetch in VS-mode with G-stage on and VS-stage Bare.
 *
 * Bug report: with G-stage translation enabled and VS-stage translation off
 * (vsatp = Bare), VS-mode cannot execute code at some valid guest-physical
 * addresses: instruction fetch raises a page fault.  Sv39x4 guest-physical
 * addresses are 41 bits wide and zero-extended.
 *
 * Root cause in the RTL (cva6_mmu.sv, instr_interface): the Sv39 canonical
 * address check on the fetch virtual address (bits [63:38] must be all 0 or
 * all 1) is applied whenever *any* translation is enabled.  When only the
 * G-stage is active, the fetch VA is the 41-bit, zero-extended GPA, so any
 * fetch with GPA bit 39 or bit 40 set is rejected with INSTR_PAGE_FAULT
 * although the GPA is perfectly valid (the data path is not affected: its
 * canonical check is gated on the S/VS-stage being enabled).
 *
 * Test plan:
 *   M-mode setup:
 *     - PMP allows everything (also for the implicit PTW fetches).
 *     - G-stage (Sv39x4) root table `g_root` gets one 1 GiB leaf:
 *         GPA 0x1000_0000_0000 (idx = GPA[40:30] = 1024) -> HPA 0x8000_0000
 *       which is where this very program is linked.  vsatp stays Bare and
 *       hgatp is enabled (MODE = Sv39 => Sv39x4 in the G-stage, VMID = 0).
 *     - mret into VS-mode at
 *         VA = 0x1000_0000_0000 + off   where off = vs_body - 0x8000_0000
 *       i.e. a high GPA whose G-stage translation lands on the .text of this
 *       program (HPA 0x8000_0000 + off).
 *   VS-mode:
 *     - a couple of instructions are fetched and executed from that high
 *       GPA; the last one is an ecall, which traps back to M-mode.
 *   M-mode:
 *     - trap_handler accepts only mcause = 10 (ENV_CALL_VSMODE, this core's
 *       ecall-from-VS-mode code) and returns to vs_done -> PASS.  Any other
 *       trap (in particular a page fault on the high-GPA fetch on the buggy
 *       core) -> FAIL(2).
 *
 * A correct core passes; on the buggy core the first instruction fetch at
 * the high GPA raises an instruction page fault and the program FAILs.
 */

#include "hyp.h"

  .text

  .globl test_main
test_main:
  /* RWX for all modes, covers the implicit PTW loads as well. */
  PMP_ALLOW_ALL

  /* Fill the G-stage root table (16 KiB, 2048 PTEs) with a single 1 GiB
   * leaf: GPA 0x1000_0000_0000 (idx = GPA[40:30] = 1024) -> HPA 0x8000_0000.
   * PTE = V|RWX|U|A|D, PPN = HPA >> 12. */
  GIGA_LEAF(g_root, 1024, 0x80000000, G_RWX)

  /* VS-stage stays explicitly Bare. */
  csrw vsatp, zero

  /* Enable G-stage translation; flush any stale G-stage TLB state. */
  HGATP_ON

  /* mepc = VA of vs_body in the VS address space:
   *   VA = 0x1000_0000_0000 + (HPA - 0x8000_0000)
   *      = HPA + 0xFF80000000  (0xFF80000000 = 2^40 - 2^31).
   *   For HPA = 0x8000_2080 this is VA = 0x1000_0002_080, a valid
   *   zero-extended 41-bit Sv39x4 GPA with bit 40 set. */
  la   t0, vs_body
  li   t1, 0xff80000000
  add  t0, t0, t1
  csrw mepc, t0

  /* mret into VS-mode: MPP = S (1), MPV = 1. */
  li   t1, 3 << 11
  csrc mstatus, t1
  li   t1, MSTATUS_MPV | (1 << 11)
  csrs mstatus, t1
  mret

  .align 2
vs_done:
  PASS

  .align 2
vs_body:
  /* Fetched and executed in VS-mode through the G-stage-mapped high GPA
   * 0x1000_0000_0000 + off.  On the buggy core the very first fetch of
   * this block raises an instruction page fault. */
  nop
  nop
  ecall

/* Only the ecall from VS-mode is expected; anything else fails.
 * This core's cause encoding (riscv_pkg.sv): ENV_CALL_VSMODE = 10
 * (ecall from VS-mode); INSTR_PAGE_FAULT = 12; INSTR_GUEST_PAGE_FAULT = 20. */
  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li   t1, 10
  beq  t0, t1, vs_return
  FAIL(2)
vs_return:
  la   t0, vs_done
  csrw mepc, t0
  li   t1, 3 << 11
  csrc mstatus, t1
  csrs mstatus, t1
  mret

/* Page tables: 16 KiB G-stage root (hgatp base must be 16 KiB aligned) and
 * 4 KiB VS-stage root.  HYP_TABLES starts a .data section. */
HYP_TABLES
