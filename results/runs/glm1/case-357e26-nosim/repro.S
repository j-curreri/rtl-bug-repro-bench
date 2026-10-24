/* repro.S -- regression test for a CVA6 PMP bug in TOR mode with grain G=1.
 *
 * Bug: a TOR PMP entry using a pmpaddr value whose lowest bit is set (i.e.,
 * pmpaddr<<2 lands 4 bytes into an 8-byte granule) is compared byte-exactly
 * against the accessed address, so the partially-covered granule at the top
 * of the TOR range is wrongly protected.  A U-mode access at the granule
 * boundary is then checked against the wrong (deny) entry instead of the
 * entry that follows.
 *
 * Spec-correct behaviour (RISC-V priv. spec, PMP grain): with G >= 1 the
 * lowest grain bits of the pmpaddr definition of the range are ignored at
 * match time, so a TOR range whose end is pmpaddr<<2 = 8*k+4 protects only
 * granules fully contained in the byte range, i.e. [.., 8k).  The byte in
 * the partially covered granule must NOT be denied by that entry.
 *
 * Test layout (all addresses 8-byte granule aligned at T):
 *   entry0 : TOR, RWX      [0,        T)   -- code/stack/data below T
 *   entry1 : TOR, ---,     [T,        T+4) -- pmpaddr1 = T/4+1, bit0 set
 *   entry2 : TOR, RWX      [T+4,      2^56)
 * T is the first free granule above the harness stack (link.ld ends at
 * 0x80007200), so it touches no live harness memory.
 * T and T+4 lie in the same 8-byte granule [T, T+8); the byte range of
 * entry1 covers only the 4 low bytes of it.
 *
 * U-mode then tries writes to T and to T+4, and M-mode inspects whether
 * they landed:
 *   - correct core, range rounded down to [T, T):  both writes land -> PASS
 *     (variants that clear granule bits of pmpaddr behave identically)
 *   - correct core, granule extended to [T, T+8):  both writes denied -> PASS
 *   - buggy core (byte-exact [T, T+4) deny):       T denied but T+4 lands
 *                                                  -> neither PASS condition
 *                                                  holds -> FAIL(1)
 * Unexpected traps (the denied probes) are skipped in the handler; only the
 * combination above fails. */

#include "test.h"

  .section .text

  .equ T_BASE, 0x80008000            /* probe granule, 8-byte aligned  */
  .equ P0,     0x20002000            /* T>>2, granule aligned, bit0=0  */
  .equ P1,     0x20002001            /* (T+4)>>2, bit0=1 (grain bit)   */
  .equ P2,     0x3FFFFFFFFFFFFF      /* TOR end for top of PLEN range  */
  .equ CFG0,   0x000F080F            /* e0 RWX, e1 ---, e2 RWX, e3 --- */

  .globl test_main
  .globl trap_handler

/* --------------------------------------------------------------------- *
 * Trap handler: swap to the M-mode stack, then either skip a denied
 * probe (4-byte instructions, all traps are the probes) or, on a
 * user-mode ecall, resume control flow in M-mode at mresume_m.
 * --------------------------------------------------------------------- */
  .align 2
trap_handler:
  csrrw sp, mscratch, sp             /* sp := M stack, mscratch := U sp  */
  sd t0, -8(sp)
  sd t1, -16(sp)

  csrr t0, mcause
  li t1, 8                           /* user ecall: go back to M-mode    */
  beq t0, t1, versum_dispatch

  /* Access fault on a probe: continue after the faulting instruction. */
  csrr t1, mepc
  addi t1, t1, 4
  csrw mepc, t1
  ld t1, -16(sp)
  ld t0, -8(sp)
  csrrw sp, mscratch, sp             /* swap U sp back                   */
  mret

versum_dispatch:
  la t0, mresume_m
  csrw mepc, t0
  li t1, (3 << 11)                   /* mret into M-mode                 */
  csrs mstatus, t1
  ld t1, -16(sp)
  ld t0, -8(sp)
  /* keep sp on the M-mode stack; mresume_m runs in M-mode */
  mret

/* --------------------------------------------------------------------- */
test_main:
  /* Point mscratch at the handler's own stack area. */
  la t0, hstack_top
  csrw mscratch, t0
  la t0, trap_handler                /* (crt already set it; be explicit) */
  csrw mtvec, t0

  /* Program the PMP entries (unlocked -> M-mode is still bypassed). */
  li t0, P0
  csrw pmpaddr0, t0
  li t0, P1
  csrw pmpaddr1, t0
  li t0, P2
  csrw pmpaddr2, t0
  li t0, CFG0
  csrw pmpcfg0, t0

  /* Baseline: clear both probe words from M-mode so any later change is
   * attributable to the U-mode probes only. */
  li t0, 0
  li t1, T_BASE
  sw t0, 0(t1)
  li t2, T_BASE + 4
  sw t0, 0(t2)

  /* Hand control to U-mode. */
  ENTER_MODE(0, umode_probe)
  unimp                              /* mret must not come back here */

/* --------------------- U-mode probe sequence -------------------------- */
  .align 2
umode_probe:
  .option push
  .option norvc                      /* faults here are skipped by +4 */
  li a1, 0x1234
  li a2, T_BASE
  sw a1, 0(a2)                       /* denied by buggy core        */
  li a3, 0x5678
  li a4, T_BASE + 4
  sw a3, 0(a4)                       /* allowed everywhere          */
  ecall                              /* user ecall: back to M-mode  */
  .option pop

/* ---------------- M-mode verdict (PMP bypassed) ----------------------- */
  .align 2
mresume_m:
  li t2, T_BASE
  lw t0, 0(t2)
  li t1, 0x1234
  beq t0, t1, 1f                     /* byte at T was writable -> GRAIN bit ignored -> PASS */

  li t2, T_BASE + 4
  lw t0, 0(t2)
  li t1, 0x5678
  bne t0, t1, 1f                     /* byte at T+4 protected too (granule extended) -> PASS */

  FAIL(1)                            /* odd corner: T denied, T+4 allowed -> bug */
1: PASS

/* ---------------- handler stack --------------------------------------- */
  .section .data
  .align 8
hstack:
  .space 512
hstack_top: