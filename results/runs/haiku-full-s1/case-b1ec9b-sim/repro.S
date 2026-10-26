#include "test.h"

/* Bug: MRET into S-mode must clear mstatus.MPRV. If it does not, M-mode loads after
 * returning are checked with the MPP privilege (U after the MRET) instead of M.
 * A PMP entry denies U-mode access to one page, so such a load faults. */

  .section .text
  .globl test_main
test_main:
  /* PMP entry 0: NAPOT 4 KiB at probe_page, no permissions (higher priority).
   * PMP entry 1: NAPOT over all memory, RWX. M-mode is not restricted by unlocked entries. */
  la t0, probe_page
  srli t0, t0, 2
  ori t0, t0, 0x1ff
  csrw pmpaddr0, t0
  li t0, -1
  csrw pmpaddr1, t0
  li t0, 0x1f18
  csrw pmpcfg0, t0

  /* Set MPRV with MPP = S, then MRET to S-mode. */
  li t0, (3 << 11)
  csrc mstatus, t0
  li t0, (1 << 11)
  csrs mstatus, t0
  li t0, (1 << 17)
  csrs mstatus, t0
  la t0, s_entry
  csrw mepc, t0
  mret

s_entry:
  ecall

/* Trap handler: ecall from S-mode returns to M-mode code at `back`; anything else fails. */
  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 9
  bne t0, t1, 1f
  la t1, back
  jr t1
1:
  FAIL(2)

back:
  /* MPRV must be clear here; a load from the denied page must then succeed. */
  la t0, probe_page
  ld t1, 0(t0)
  PASS

  .section .data
  .align 12
probe_page:
  .space 4096
