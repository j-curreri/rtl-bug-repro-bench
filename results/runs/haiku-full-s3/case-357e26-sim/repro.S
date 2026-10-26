#include "test.h"

/* PMP G=1 (8-byte grain): in TOR mode pmpaddr[0] is ignored, so
 * pmpaddr0 = (B >> 2) | 1 still bounds the region at B (8-byte aligned).
 * Entry 0 grants RWX over [0, B). An 8-byte load at B is outside the region,
 * no other entry matches, and U-mode has no default permission, so a correct
 * core raises a load access fault (mcause 5). The buggy core treats the bound
 * as B + 4, matches the load, and it succeeds. */

#define BOUND 0x80100000

  .section .text
  .globl test_main
test_main:
  li t0, BOUND
  srli t0, t0, 2
  ori t0, t0, 1
  csrw pmpaddr0, t0
  li t0, 0x0f            /* A=TOR, R=W=X=1 */
  csrw pmpcfg0, t0
  ENTER_MODE(0, user_code)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t6, mcause
  li t5, 5               /* load access fault: expected on a correct core */
  beq t6, t5, 1f
  FAIL(1)
1:
  PASS

  .align 2
user_code:
  li t0, BOUND
  ld t1, 0(t0)          /* must fault on a correct core */
  ecall                 /* reached only if the load was allowed */
