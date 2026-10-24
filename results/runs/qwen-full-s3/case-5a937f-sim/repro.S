/* Reproducer: CVA6 menvcfg/senvcfg CBIE WARL bug.
 *
 * The CBIE field of menvcfg (0x30A) and senvcfg (0x10A) occupies bits [5:4]
 * and is WARL: the legal encodings are 2'b00, 2'b01 and 2'b11; 2'b10 is
 * reserved and must NEVER be read back. The buggy core stores the reserved
 * encoding when software writes it, so a later read of the register returns
 * the reserved value. A correct core maps a write of 2'b10 to one of the
 * legal encodings (in particular never to 2'b10).
 *
 * Note: field value 2'b10 sits in bits [5:4] => register value 0x20
 * (bit 5 only). 0x30 would be the legal 2'b11 encoding.
 *
 * (henvcfg is not tested: this configuration does not implement the
 * hypervisor extension, so the access would trap on both cores.)
 *
 * Buggy core:  readback of menvcfg[5:4] == 2'b10 (0x20) -> FAIL(1)
 * Correct core: readback never shows 2'b10                  -> PASS
 */
#include "test.h"

  .globl test_main
test_main:
  /* --- menvcfg: write reserved CBIE encoding 2'b10, read it back --- */
  li   t0, 0x20                 /* CBIE[5:4] = 2'b10 (reserved) */
  csrw menvcfg, t0
  csrr t0, menvcfg
  andi t0, t0, 0x30             /* isolate the CBIE field */
  li   t1, 0x20
  bne  t0, t1, menvcfg_ok
  FAIL(1)                       /* reserved value read back from menvcfg */

menvcfg_ok:
  /* --- senvcfg: same check on the supervisor configuration --- */
  li   t0, 0x20
  csrw senvcfg, t0
  csrr t0, senvcfg
  andi t0, t0, 0x30
  li   t1, 0x20
  bne  t0, t1, senvcfg_ok
  FAIL(2)                       /* reserved value read back from senvcfg */

senvcfg_ok:
  PASS
