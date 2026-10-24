/* repro.S - bug reproducer for CVA6 (cv64a6_imafdch_sv39)
 *
 * Bug: with G-stage translation enabled and VS-stage translation off
 * (vsatp = Bare), VS-mode cannot execute code at some valid guest-physical
 * addresses: instruction fetch raises a page fault.
 *
 * Root cause: in cva6_mmu.sv the instruction-fetch "canonical address" check
 * applies the Sv39 39-bit rule (bits [XLEN-1 : SV-1] all 0 or all 1) to the
 * fetch address whenever *any* translation stage is enabled.  In a
 * G-stage-only configuration (V=1, vsatp=Bare, hgatp=Sv39x4) the fetch
 * address is not a 39-bit virtual address but a 41-bit guest-physical
 * address (Sv39x4 GPAs are 41 bits wide and zero-extended).  Any valid GVA
 * with bit 38, 39 or 40 set therefore has mixed bits in [63:38] and the
 * check spuriously raises an instruction page fault.  The equivalent check
 * on the data path is gated on the S/VS stage only, so loads/stores work -
 * only instruction fetch is affected.
 *
 * Strategy:
 *  - Build a G-stage (Sv39x4) root table with two 1 GiB leaves:
 *      g_root[1024]: GVA [2^40, 2^40 + 1G) -> DRAM @ 0x80000000
 *      g_root[512] : GVA [2^39, 2^39 + 1G) -> DRAM @ 0x80000000
 *    Both target addresses are valid 41-bit GPAs (bit 40 / bit 39 set).
 *  - Enable G-stage (hgatp = Sv39x4), leave vsatp = Bare, mret into VS-mode
 *    at a GPA in the 2^40 window.
 *  - On a correct core the guest code executes, verifies a G-stage load
 *    through the 2^39 window, then writes PASS to `tohost` through the GVA.
 *  - On the buggy core the very first instruction fetch in VS-mode raises a
 *    (guest) page fault; the trap lands in HS-mode at stvec and the handler
 *    reports FAIL.
 */
#include "hyp.h"

  HYP_TABLES

/* .data object used to verify G-stage data translation from VS-mode. */
  .section .data.repro, "aw"
marker: .dword 0x12345678
  .section .text

  .globl test_main
test_main:
  /* PMP entry 0: RWX over the whole address space, all modes. */
  PMP_ALLOW_ALL

  /* G-stage root: 1 GiB leaves into DRAM.  (pa >> 12 << 10) keeps PPN[9:0]=0
   * and for pa = 0x80000000 the PPN is 1 GiB aligned, as required for a
   * G-stage giga-page leaf. */
  GIGA_LEAF(g_root, 1024, 0x80000000, G_RWX)   /* GVA [2^40, 2^40+1G)  */
  GIGA_LEAF(g_root, 512,  0x80000000, G_RWX)   /* GVA [2^39, 2^39+1G)  */

  /* Enable G-stage translation (Sv39x4, VMID 0); keep vsatp = Bare. */
  HGATP_ON
  csrw vsatp, zero

  /* Guest traps (V=1) are taken in HS-mode at stvec. */
  la t0, trap_handler
  csrw stvec, t0

  /* Target GPA of the guest code: 2^40 + offset of guest_code within the
   * 1 GiB window (HPA[29:0] of the program image). */
  la t0, guest_code
  li t1, 0x80000000
  sub t0, t0, t1
  li t1, (1 << 40)
  add t0, t0, t1
  csrw mepc, t0

  /* mret into VS-mode: MPP=S, MPV=1. */
  li t0, MSTATUS_MPV
  csrs mstatus, t0
  li t0, (3 << 11)
  csrc mstatus, t0
  li t0, (1 << 11)
  csrs mstatus, t0
  mret

/* Executed in VS-mode: G-stage on, VS-stage off. */
guest_code:
  /* GVA of `tohost` in the 2^40 window (HPA[29:0] offset, HPA < 2^31+2^30). */
  la t4, tohost
  li t0, 0x80000000
  sub t4, t4, t0
  li t0, (1 << 40)
  add t4, t4, t0

  /* G-stage data translation check: load `marker` through the 2^39 window. */
  la t0, marker
  li t1, 0x80000000
  sub t0, t0, t1
  li t1, (1 << 39)
  add t0, t0, t1
  ld t2, 0(t0)
  li t3, 0x12345678
  bne t2, t3, guest_fail

  /* Everything worked: report PASS by writing to `tohost` through the GVA. */
  li a0, 1
  sd a0, 0(t4)
1:  j 1b

guest_fail:
  /* G-stage data check failed: report FAIL(5) through the GVA. */
  li a0, (5 << 1) | 1
  sd a0, 0(t4)
2:  j 2b

/* Any trap reaching here means the reproducer failed: on a correct core the
 * guest never traps.  Runs in HS-mode (guest traps) or M-mode alike. */
  .globl trap_handler
  .align 2
trap_handler:
  FAIL(127)
