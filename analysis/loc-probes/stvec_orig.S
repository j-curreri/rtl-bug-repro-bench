/* Vectored-mode stvec: an S-mode interrupt must trap to BASE + 4*cause, where
 * BASE is the value stvec reads back (stvec.BASE is WARL, so a core may align it).
 *
 * The core keeps every BASE bit writable, but computes the vectored target by
 * overwriting address bits [7:2] with the cause instead of adding 4*cause. With
 * a BASE that is 64-byte but not 256-byte aligned, a supervisor software
 * interrupt (cause 1) lands at (BASE & ~0xfc) | 0x4 instead of BASE + 4.
 *
 * Every word of a 512-byte sled is "jal t3, s_landed", so wherever the trap lands
 * the handler can recover the landing address (t3 - 4) and compare it with the
 * address required by the specification. */
#include "test.h"

  .option norvc
  .text
  .globl test_main
  .globl trap_handler

/* M-mode handler: only the final ecall from S (cause 9) is expected. */
  .align 4
trap_handler:
  csrr t0, mcause
  li t1, 9
  bne t0, t1, unexpected
  beqz a1, wrong_target
  PASS
wrong_target:
  FAIL(1)
unexpected:
  FAIL(2)

test_main:
  PMP_ALLOW_ALL

  /* Delegate the supervisor software interrupt to S-mode and enable it. */
  li t0, 2
  csrw mideleg, t0
  csrw mie, t0

  /* stvec = sled + 0x40 (64-byte aligned, not 256-byte aligned), vectored mode. */
  la t0, sled
  addi t0, t0, 0x40
  ori t0, t0, 1
  csrw stvec, t0
  csrr s0, stvec

  /* Required trap target: BASE + 4*1 if vectored, BASE if direct. */
  andi t1, s0, 3
  andi s1, s0, -4
  li t2, 1
  bne t1, t2, 1f
  addi s1, s1, 4
1:
  /* SSIP pending; not taken in M-mode because it is delegated. */
  csrs mip, t0
  ENTER_MODE(1, s_entry)

s_entry:
  li a1, 0
  csrsi sstatus, 2          /* SIE=1: the pending SSIP is taken now */
  nop
  nop
  nop
  nop
  /* The interrupt was never taken. */
  li a1, 0
  ecall

/* S-mode handler, reached through the sled. */
s_landed:
  addi t3, t3, -4           /* address where the trap landed */
  csrci sstatus, 2
  csrci sip, 2
  li a1, 0
  bne t3, s1, 2f
  li a1, 1
2:
  ecall

  .align 8
sled:
  .rept 128
  jal t3, s_landed
  .endr
