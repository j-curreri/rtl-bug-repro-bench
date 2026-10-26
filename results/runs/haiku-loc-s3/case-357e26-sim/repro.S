#include "test.h"

/*
 * PMP TOR matching with G=1 (8-byte granularity): pmpaddr[0] is not part of the
 * match, so a TOR boundary written as (D>>2)|1 must still end at D (8-byte aligned).
 * Entry 0 is TOR RWX covering [0, D); D itself is outside it. An S-mode load at D
 * must therefore fault (load access fault, mcause 5) and PASS.
 * This core compares against D+4 and lets the load succeed, which reaches the ecall
 * and FAILs.
 */

  .section .text
  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 5
  beq t0, t1, 1f
  FAIL(2)
1:
  PASS

  .globl test_main
  .align 2
test_main:
  li t0, 0x80100000
  srli t0, t0, 2
  ori t0, t0, 1
  csrw pmpaddr0, t0
  csrw pmpaddr1, zero
  li t0, 0x0f            /* entry 0: A=TOR (0x08), R|W|X (0x07) */
  csrw pmpcfg0, t0
  ENTER_MODE(1, s_mode)

s_mode:
  li t0, 0x80100000
  lw t1, 0(t0)           /* must fault: D is outside [0, D) */
  ecall                  /* reached only if the load was allowed */
