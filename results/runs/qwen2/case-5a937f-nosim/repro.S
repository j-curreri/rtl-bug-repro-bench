#include "test.h"

/* Bug: the CBIE field of menvcfg/senvcfg/henvcfg is WARL and has only three
 * legal encodings (2'b00, 2'b01, 2'b11); 2'b10 is reserved and must never
 * be read back. In this core the CBIE field lives in bits [5:4] of the
 * register (mask 0x30). The CSR write paths of menvcfg/senvcfg/henvcfg map
 * a written 2'b10 to the reserved encoding and store it, so after
 * `csrw <reg>, 0x20` the CBIE field reads back the reserved value 0x20.
 *
 * A core that honors the spec sanitizes the write to a legal encoding, so
 * the readback & 0x30 is 0x00, 0x10 or 0x30 - and this test ends with PASS.
 * On the buggy core the readback is 0x20 and the test FAILs. */

  .globl test_main
test_main:
  PMP_ALLOW_ALL

  li t1, 0x20          /* reserved CBIE encoding 2'b10 in bits [5:4] */

  /* menvcfg (CSR 0x30A): write CBIE = 2'b10, read it back */
  li t0, 0x20
  csrw menvcfg, t0
  csrr t0, menvcfg
  andi t0, t0, 0x30
  bne t0, t1, 1f
  FAIL(1)
1:

  /* senvcfg (CSR 0x10A): same */
  li t0, 0x20
  csrw senvcfg, t0
  csrr t0, senvcfg
  andi t0, t0, 0x30
  bne t0, t1, 2f
  FAIL(2)
2:

  /* henvcfg (CSR 0x60A): same */
  li t0, 0x20
  csrw henvcfg, t0
  csrr t0, henvcfg
  andi t0, t0, 0x30
  bne t0, t1, 3f
  FAIL(3)
3:

  PASS

/* Any trap while running this test is a failure. */
  .globl trap_handler
  .align 2
trap_handler:
  csrr t6, mcause
  FAIL(127)
