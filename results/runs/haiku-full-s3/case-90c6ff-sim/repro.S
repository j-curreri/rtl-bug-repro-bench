#include "hyp.h"

/* VS-mode fetch with vsatp = Bare at a valid 41-bit guest-physical address whose
 * bit 40 is set (bits 63:41 zero, so the GPA is valid and zero-extended). The
 * G-stage maps it with one 1 GiB leaf onto DRAM at 0x80000000. A correct core runs
 * the VS-mode `ecall` and traps to M-mode with cause 10; the buggy core applies the
 * 39-bit canonical check to the fetch address and page-faults instead. */

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* G-stage: GPA [0x100_0000_0000, +1 GiB) -> PA [0x8000_0000, +1 GiB) */
  GIGA_LEAF(g_root, 1024, 0x80000000, G_RWX)
  HGATP_ON
  csrw vsatp, zero

  /* mepc = GPA of vs_code = (1 << 40) + (vs_code - 0x80000000) */
  la t0, vs_code
  li t1, 0x80000000
  sub t0, t0, t1
  li t1, (1 << 40)
  add t0, t0, t1
  csrw mepc, t0

  /* mret into VS-mode (MPP = S, MPV = 1) */
  li t0, MSTATUS_MPV
  csrs mstatus, t0
  li t0, (3 << 11)
  csrc mstatus, t0
  li t0, (1 << 11)
  csrs mstatus, t0
  mret

vs_code:
  ecall

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 10
  bne t0, t1, 1f
  PASS
1:
  csrr t6, mcause
  FAIL(127)

HYP_TABLES
