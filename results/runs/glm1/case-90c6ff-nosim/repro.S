/* repro.S
 *
 * Bug: with G-stage translation on (hgatp = Sv39x4) and VS-stage off
 * (vsatp = Bare), VS-mode instruction fetch at some valid guest-physical
 * addresses raises a spurious page fault.  Sv39x4 GPAs are 41 bits wide,
 * zero-extended.
 *
 * Root cause: the fetch path in cva6_mmu.sv checks Sv39 canonicality on
 * bits [63:38] whenever (en_translation | en_g_translation), even though with
 * vsatp = Bare the fetch address is a GPA, so every valid GPA >= 2^38 trips
 * the check while the data path (g_overflow, SVX = 41) treats it as valid.
 *
 * The program:
 *   1. builds a G-stage root with one 1 GiB leaf mapping
 *      GPA [2^38, 2^38 + 1 GiB)  ->  HPA 0x80000000,
 *   2. enables only the G-stage (vsatp = Bare) and enters VS-mode at
 *      GPA(vs_code) = HPA(vs_code) + (2^38 - 0x80000000),
 *   3. PASSes when those fetches succeed on correct RTL; on the buggy RTL the
 *      first VS-mode fetch faults (mcause = 12) into the trap handler -> FAIL.
 */
#include "hyp.h"

  .text
  .globl trap_handler
  .align 2
trap_handler:
  csrr t6, mcause            /* 12 = INSTR_PAGE_FAULT expected on buggy core */
  FAIL(3)

  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* g_root[256]: GPA [2^38, 2^38 + 1 GiB) -> HPA 0x80000000 (1 GiB leaf) */
  GIGA_LEAF(g_root, 256, 0x80000000, G_RWX)

  HGATP_ON                   /* hgatp = Sv39x4 (g_root), hfence.gvma         */
  csrw vsatp, zero           /* VS-stage translation off: Bare               */

  /* mepc = GPA(vs_code) = HPA(vs_code) + 2^38 - 0x80000000 */
  la   t0, vs_code
  li   t1, 0x380000000
  add  t0, t0, t1

  /* mstatus: MPP = S, MPV = 1  ->  mret enters VS-mode */
  li   t2, (1 << 11)
  csrs mstatus, t2
  li   t2, MSTATUS_MPV
  csrs mstatus, t2

  csrw mepc, t0
  mret

vs_code:                     /* runs at GPA 0x400002xxx (bit 38 set) */
  PASS                       /* li a0, 1; j _halt                    */

  HYP_TABLES