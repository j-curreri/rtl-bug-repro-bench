/*
 * Reproducer for: MRET to a less-privileged mode (S-mode) does not clear MPRV.
 *
 * The privileged spec requires that when MRET transfers control to a mode less
 * privileged than M, MPRV (mstatus bit 17) is cleared to 0.  On this buggy core
 * the clear only happens when CVA6Cfg.RVH is enabled, which is 0 here, so MPRV
 * survives the MRET.
 *
 * Strategy
 *  --------
 *  1. In M-mode, enable Sv39 translation with a hand-built page table that maps
 *     the S-mode trampoline page but deliberately leaves one 4 KiB page
 *     (M_DATA_PA) unmapped.  Write a known value to M_DATA_PA physically.
 *  2. Set MPRV=1 and MPP=S, then MRET into the S-mode trampoline.
 *       - correct core: MPRV cleared to 0 by the MRET.
 *       - buggy core:   MPRV stays 1.
 *  3. The S-mode trampoline issues an ECALL, which traps to M-mode with
 *       mcause=9 (environment call from S-mode) and MPP=S.  MPRV is not changed
 *       by the trap, so it is still 1 on the buggy core and 0 on the correct one.
 *  4. In the M-mode trap handler, load M_DATA_PA.  MPRV affects only load/store
 *     translation (never instruction fetch), so:
 *       - correct core (MPRV=0): M-mode load, no translation -> reads the value
 *         we wrote -> PASS.
 *       - buggy core (MPRV=1, MPP=S): the load is translated as S-mode through
 *         the Sv39 table, where M_DATA_PA is unmapped -> load page fault -> the
 *         handler re-enters with an unexpected mcause -> FAIL.
 */

#include "hyp.h"

  .globl test_main
  .globl trap_handler

  # Physical page we write to but intentionally do NOT map in Sv39.
  .equ M_DATA_PA, 0x80010000
  .equ M_VAL,     0x1122334455667788

  # PTE flag encodings for this core (A=0x40, D=0x80).
  .equ PTE_TBL,   0x1     # V            -> valid table pointer
  .equ PTE_LF,    0xcf    # V|R|W|X|A|D  -> valid 4 KiB leaf

  # ---------------- Sv39 page-table pages (4 KiB each, page aligned) -------
  .section .data
  .align 12
  .globl pt_root3
pt_root3: .space 4096
  .align 12
  .globl pt_root2
pt_root2: .space 4096
  .align 12
  .globl pt_root1
pt_root1: .space 4096

  .section .text
  .align 2
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  # Write the known value to M_DATA_PA (physical; no translation yet).
  li   t0, M_DATA_PA
  li   t1, M_VAL
  sd   t1, 0(t0)

  # root3[2] -> root2  (both in the 1 GiB region [0x8000_0000, 0x9000_0000))
  la   t0, pt_root3
  la   t1, pt_root2
  srli t1, t1, 12
  slli t1, t1, 10
  li   t2, PTE_TBL
  or   t1, t1, t2
  li   t3, 16                # index 2 * 8
  add  t3, t0, t3
  sd   t1, 0(t3)

  # root2[0] -> root1
  la   t0, pt_root2
  la   t1, pt_root1
  srli t1, t1, 12
  slli t1, t1, 10
  li   t2, PTE_TBL
  or   t1, t1, t2
  sd   t1, 0(t0)            # index 0

  # root1[2] = identity 4 KiB leaf for the page holding the S-mode trampoline.
  #           M_DATA_PA's page (index 0x10) is left at 0 -> unmapped.
  la   t0, pt_root1
  la   t1, s_code
  srli t1, t1, 12
  slli t1, t1, 10
  li   t2, PTE_LF
  or   t1, t1, t2
  li   t3, 16               # index 2 * 8
  add  t3, t0, t3
  sd   t1, 0(t3)

  fence

  # Enable Sv39: mode=8 in the top 4 bits, root PPN in the low 44 bits.
  la   t0, pt_root3
  srli t0, t0, 12
  li   t1, SATP_SV39
  or   t0, t0, t1
  csrw satp, t0
  sfence.vma

  # Set MPRV=1, then MRET to S-mode.  A correct core clears MPRV here; the
  # buggy core leaves it set.
  li   t0, 0x20000          # MSTATUS.MPRV
  csrs mstatus, t0
  ENTER_MODE(1, s_code)

  # If we ever fall through the MRET, that is not the intended path.
  FAIL(20)

  .align 2
s_code:
  ecall                     # S-mode env call -> M-mode, mcause=9, MPP=S
  j s_code                  # hang if somehow not trapped (defensive)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t5, mcause
  addi t5, t5, -9           # 0 iff mcause == 9 (S-mode ecall)
  bnez t5, trap_fail        # any other cause is an unexpected fault -> bug
  li   t0, M_DATA_PA
  ld   t6, 0(t0)            # differentiating load; faults on the buggy core
  li   t1, M_VAL
  bne  t6, t1, data_bad
  PASS
data_bad:
  FAIL(2)
trap_fail:
  FAIL(3)
