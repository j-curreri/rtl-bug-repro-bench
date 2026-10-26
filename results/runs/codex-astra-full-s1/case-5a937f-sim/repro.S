#include "test.h"

  .section .text
  .balign 4
  .globl test_main
test_main:
  /* menvcfg (0x30a), CBIE = bits [5:4]. Preserve all other fields. */
  csrr t0, 0x30a
  li t1, -49                    /* ~0x30 */
  and t1, t0, t1
  ori t1, t1, 0x20              /* Reserved CBIE encoding 0b10. */
  csrw 0x30a, t1
  csrr t2, 0x30a
  csrw 0x30a, t0                /* Restore the original configuration. */

  /* WARL may choose any legal encoding: 00, 01, or 11. */
  andi t2, t2, 0x30
  li t3, 0x20
  beq t2, t3, reserved_readback
  PASS

reserved_readback:
  FAIL(1)

  .balign 4
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  FAIL(2)
