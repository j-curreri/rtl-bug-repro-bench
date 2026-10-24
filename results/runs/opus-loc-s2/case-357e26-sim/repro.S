#include "test.h"

/* PMP granularity on this core is G=1 (8 bytes): NA4 is not selectable and
 * pmpaddr[0] reads as 0 in TOR/OFF mode. The privileged spec requires that
 * pmpaddr[G-1:0] do not affect TOR address matching. pmp_entry compares the
 * raw stored pmpaddr instead, so an odd pmpaddr extends the TOR top by 4 bytes.
 *
 * entry0: OFF,  pmpaddr0 = (buf+8)>>2         (lower bound, even)
 * entry1: TOR,  pmpaddr1 = ((buf+24)>>2) | 1  (effective top = buf+24), no perms
 * entry2: NAPOT all memory, RWX
 * From U-mode: load buf+20 must fault, load buf+24 must not. */

  .text
  .globl test_main
test_main:
  li s10, 0
  li t0, -1
  csrw pmpaddr2, t0
  la t0, buf+8
  srli t0, t0, 2
  csrw pmpaddr0, t0
  la t0, buf+24
  srli t0, t0, 2
  ori t0, t0, 1
  csrw pmpaddr1, t0
  li t0, 0x1f0800        /* cfg0 OFF, cfg1 TOR ---, cfg2 NAPOT RWX */
  csrw pmpcfg0, t0
  ENTER_MODE(0, user)

user:
  /* inside the TOR region: must fault */
  li s1, 0
  la t3, buf
  lw t4, 20(t3)
  li s10, 1
  beqz s1, done
  /* at the effective top bound: must not fault */
  li s1, 0
  lw t4, 24(t3)
  li s10, 2
  bnez s1, done
  li s10, 0
done:
  ecall

  .globl trap_handler
  .align 2
trap_handler:
  csrr t5, mcause
  li t6, 8               /* ecall from U: finish */
  beq t5, t6, finish
  li t6, 5               /* load access fault: note it and skip */
  bne t5, t6, unexpected
  li s1, 1
  csrr t5, mepc
  addi t5, t5, 4
  csrw mepc, t5
  mret
finish:
  bnez s10, fail
  PASS
fail:
  li t6, 1
  beq s10, t6, fail1
  FAIL(2)
fail1:
  FAIL(1)
unexpected:
  FAIL(3)

  .data
  .align 6
buf: .space 64
