/* VS-mode fetch from a guest-physical address with bit 38 set (vsatp = Bare,
 * G-stage Sv39x4 on). GPA 0x40_8000_0000 is a valid 41-bit Sv39x4 GPA and is
 * mapped by G-stage onto DRAM at 0x8000_0000. A correct core executes the code
 * there and the ecall traps to M-mode with cause 10; the buggy core treats the
 * GPA as a non-canonical Sv39 VA and raises an instruction page fault. */
#include "hyp.h"

#define HI_OFF  0x4000000000          /* GPA bit 38 */

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* GPA 0x8000_0000 -> PA 0x8000_0000 (index 2) */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  /* GPA 0x40_8000_0000 -> PA 0x8000_0000 (index 0x102) */
  GIGA_LEAF(g_root, 0x102, 0x80000000, G_RWX)
  csrw vsatp, zero
  HGATP_ON
  li t0, MSTATUS_MPV
  csrs mstatus, t0
  li t0, (3 << 11)
  csrc mstatus, t0
  li t0, (1 << 11)
  csrs mstatus, t0
  la t0, vs_code
  li t1, HI_OFF
  add t0, t0, t1
  csrw mepc, t0
  mret

  .align 2
vs_code:
  li a1, 0x1234
vs_ecall:
  ecall
1: j 1b

  .align 2
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  li t5, 10                 /* environment call from VS-mode */
  bne t6, t5, bad_cause
  li t5, 0x1234
  bne a1, t5, bad_reg
  la t0, vs_ecall
  li t1, HI_OFF
  add t0, t0, t1
  csrr t2, mepc
  bne t0, t2, bad_epc
  PASS
bad_cause:
  FAIL(1)
bad_reg:
  FAIL(2)
bad_epc:
  FAIL(3)

  HYP_TABLES
