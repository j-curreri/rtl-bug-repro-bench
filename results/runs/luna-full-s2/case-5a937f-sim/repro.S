#include "test.h"

  .macro CHECK_CBIE csr, code
  csrr t0, \csr
  li   t1, -49             /* clear CBIE[5:4] */
  and  t0, t0, t1
  ori  t0, t0, 0x20        /* write reserved encoding 2'b10 */
  csrw \csr, t0
  csrr t0, \csr
  andi t0, t0, 0x30
  li   t1, 0x20
  bne  t0, t1, 1f
  li   a0, ((\code << 1) | 1)
  j    _halt
1:
  .endm

  .section .text
  .globl test_main
test_main:
  /* A WARL field may coerce a reserved write to any legal value, but it
     must not preserve the reserved 2'b10 encoding. */
  CHECK_CBIE menvcfg, 1
  CHECK_CBIE senvcfg, 2
  CHECK_CBIE henvcfg, 3

  PASS
