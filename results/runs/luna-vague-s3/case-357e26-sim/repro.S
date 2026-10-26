#include "test.h"

  .section .text
  .option norvc
  .globl test_main
test_main:
  /* With PMP G=1, TOR ignores pmpaddr0 bit 0.  The architectural limit is
     cross_insn, but the buggy matcher may retain the written bit and extend
     the region by four bytes. */
  la t0, cross_insn
  srli t0, t0, 2
  ori t0, t0, 1
  csrw pmpaddr0, t0
  li t0, 0x0d                 /* TOR, R=1, X=1, W=0 */
  csrw pmpcfg0, t0

  la t0, cross_insn
  csrw mepc, t0
  li t0, (3 << 11)
  csrc mstatus, t0
  /* MPP=U (zero); retain the other mstatus fields. */
  mret

  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 1                    /* instruction access fault */
  bne t0, t1, unexpected_trap
  csrr t0, mepc
  la t1, cross_insn
  bne t0, t1, unexpected_trap
  PASS
unexpected_trap:
  FAIL(1)

  /* Put the probe on an eight-byte boundary. */
  .balign 8
  .globl cross_insn
cross_insn:
  .4byte 0x0000006f           /* jal x0, 0: buggy core loops here */
