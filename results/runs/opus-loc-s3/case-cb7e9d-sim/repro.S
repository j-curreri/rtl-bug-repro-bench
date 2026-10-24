#include "test.h"

/* mcontrol6 execute trigger, match=1 (NAPOT), tdata2 = base | 0x7 covers the
 * 16-byte range [base, base+16). Executing base+8 in U-mode must raise a
 * breakpoint exception (mcause 3). */

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  csrw tselect, zero
  csrr t0, tselect
  bnez t0, fail_sel
  la t0, target
  ori t0, t0, 0x7
  csrw tdata2, t0
  li t0, (6 << 60) | (1 << 7) | (1 << 3) | (1 << 2)
  csrw tdata1, t0
  csrr t1, tdata1
  li t2, (1 << 7) | (1 << 3) | (1 << 2)
  and t1, t1, t2
  bne t1, t2, fail_cfg
  la t0, target_entry
  li t1, (3 << 11)
  csrc mstatus, t1
  csrw mepc, t0
  mret

fail_sel: FAIL(2)
fail_cfg: FAIL(3)

  .globl trap_handler
  .align 4
trap_handler:
  csrr t0, mcause
  li t1, 3
  bne t0, t1, bad_cause
  csrr t0, mepc
  la t1, target_entry
  bne t0, t1, bad_epc
  PASS
bad_cause: FAIL(4)
bad_epc: FAIL(5)

  .align 6
target:
  .option push
  .option norvc
  nop
  nop
target_entry:
  nop
  nop
  ecall          /* outside the range: reached only if trigger did not fire */
  .option pop
