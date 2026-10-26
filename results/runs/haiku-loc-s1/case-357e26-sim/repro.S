#include "test.h"

/* Partial-overlap check. Entry 1 is a TOR region [B+4, B+12) with no access. An 8-byte
 * load at B covers [B, B+8), so it partially overlaps the region and must fail.
 * PMP matching in pmp_entry.sv only looks at the first byte of an access, so this
 * core lets the load through. The other probes are controls: a word fully inside
 * the region must fault, and accesses fully outside it must not. */
#define B 0x81000000

  .option norvc
  .section .text
  .globl test_main
test_main:
  /* entry 0: OFF, pmpaddr0 = B+4 (lower bound of entry 1)
     entry 1: TOR deny [B+4, B+12)
     entry 2: allow all */
  li s1, B
  addi t0, s1, 4
  srli t0, t0, 2
  csrw pmpaddr0, t0
  addi t0, s1, 12
  srli t0, t0, 2
  csrw pmpaddr1, t0
  li t0, -1
  csrw pmpaddr2, t0
  li t0, 0x1f0800
  csrw pmpcfg0, t0
  ENTER_MODE(1, sweep)

/* Load from t6 and return. The trap handler sets s11 on a load access fault. */
probe_d:
  ld t5, 0(t6)
  ret

probe_w:
  lw t5, 0(t6)
  ret

/* CHECK probe, offset, expect, code: expect 1 = must fault, 0 = must not fault. */
.macro CHECK probe, off, expect, code
  addi t6, s1, \off
  li s11, 0
  jal ra, \probe
  li s10, \code
  .if \expect
  beqz s11, fail_s
  .else
  bnez s11, fail_s
  .endif
.endm

sweep:
  CHECK probe_d, -8, 0, 1  /* control: [B-8, B) is outside the region */
  CHECK probe_w, 4, 1, 2   /* control: [B+4, B+8) is inside the region */
  CHECK probe_d, 0, 1, 3   /* [B, B+8) partially overlaps [B+4, B+12): must fault */
  CHECK probe_d, 8, 1, 4   /* [B+8, B+16) partially overlaps [B+4, B+12): must fault */
  CHECK probe_d, 12, 0, 5  /* control: [B+12, B+20) is outside the region */
  PASS

fail_s:
  slli a0, s10, 1
  ori a0, a0, 1
  j _halt

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 5                 /* load access fault */
  bne t0, t1, 2f
  li s11, 1
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret
2:
  FAIL(127)
