/* repro.S - reproducer for the G-stage-only VS-mode fetch bug (CVA6, cv64a6_imafdch_sv39).
 *
 * Bug: with G-stage translation enabled and VS-stage translation off
 * (vsatp = Bare), VS-mode cannot execute code at some valid guest-physical
 * addresses: instruction fetch raises a page fault.
 *
 * Sv39x4 guest-physical addresses are 41 bits wide and zero-extended, so a
 * GPA in [2^40, 2^41) is valid. The fetch path of the MMU applies the Sv39
 * 39-bit canonical rule (bits [63:38] must be all 0 or all 1) to that 41-bit
 * GPA whenever translation of any kind is enabled, so every zero-extended GPA
 * with bit 40 set is judged non-canonical and faults. A correct core instead
 * walks the G-stage table and fetches the instruction.
 *
 * This program builds a G-stage (Sv39x4) root table with a single 1 GiB leaf
 * mapping GPA [2^40, 2^40 + 1 GiB) onto the DRAM image [0x80000000, ...),
 * keeps vsatp = Bare, and enters VS-mode at a GPA inside that region. A short
 * stub is executed there and returns to M-mode via ecall:
 *
 *   - correct core: fetch/execute the stub through the G-stage table, ecall
 *     traps to M-mode, handler sees the trap in the high-GPA region -> PASS
 *   - buggy core:   first fetch at the high GPA raises an instruction
 *     (guest) page fault; the handler detects that fault -> FAIL
 */
#include "hyp.h"

HYP_TABLES

  .text
  .globl test_main

test_main:
  PMP_ALLOW_ALL

  /* G-stage root: one 1 GiB leaf at top-level index 1024
   * (the G-stage top-level index is GPA[40:30]; 2^40 >> 30 = 1024):
   *   GPA [2^40, 2^40 + 1 GiB) -> HPA [0x80000000, 0x80000000 + 1 GiB)
   * PTE flags: V|W|X|U|A|D plus R; U is required for guest fetches. */
  GIGA_LEAF(g_root, 1024, 0x80000000, G_RWX)

  /* Enable G-stage translation (Sv39x4, VMID 0). VS-stage stays off. */
  HGATP_ON
  csrw vsatp, zero

  /* High-GPA address of vs_target: GPA = 2^40 + (vs_target - 0x80000000) */
  la   t0, vs_target
  li   t1, 0x80000000
  sub  t0, t0, t1
  li   t1, 0x10000000000
  add  t0, t0, t1
  csrw mepc, t0

  /* mret into VS-mode: MPP = 1 (S), MPV = 1 (V = 1) */
  li   t0, MSTATUS_MPV
  csrs mstatus, t0
  li   t0, (3 << 11)
  csrc mstatus, t0
  li   t0, (1 << 11)
  csrs mstatus, t0
  mret

vs_target: /* executes in VS-mode at GPA 2^40 + X, physically 0x80000000 + X */
  addi s8, s8, 1
  addi s9, s9, 1
  addi s10, s10, 1
  ecall /* -> M-mode, mcause = ENV_CALL_VSMODE */

/* M-mode trap handler (overrides the weak default in crt.S). */
  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li   t1, 12 /* riscv::INSTR_PAGE_FAULT - the bug */
  beq  t0, t1, .Lfail
  li   t1, 20 /* riscv::INSTR_GUEST_PAGE_FAULT - the bug */
  beq  t0, t1, .Lfail
  /* The only expected trap is the ecall from the VS-mode stub, taken at a
   * high GPA (bit 40 set). Anything else means the stub was not executed. */
  csrr t0, mepc
  srli t0, t0, 40
  li   t1, 1
  bne  t0, t1, .Lfail
  PASS
.Lfail:
  FAIL(127)
