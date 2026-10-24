/* PMP granularity is G=1 (8 bytes, see the OFF/TOR read-back of pmpaddr[0] = 0).
 * Per the privileged spec, only for G >= 2 do NAPOT bits pmpaddr[G-2:0] read as ones;
 * with G = 1 no bit is forced in NAPOT mode, so pmpaddr reads back the written value.
 * The buggy core forces pmpaddr[0] = 1 on reads of a NAPOT entry. */
#include "test.h"

.text
.global test_main
test_main:
  /* entry 1: NAPOT, no permissions (not locked, so M-mode is unaffected) */
  csrw pmpcfg0, zero
  li   t0, 0x20001000          /* even: 8-byte NAPOT region at 0x80004000 */
  csrw pmpaddr1, t0
  li   t1, (0x18 << 8)         /* pmp1cfg.A = NAPOT */
  csrw pmpcfg0, t1
  csrr t2, pmpcfg0
  bne  t2, t1, fail1           /* NAPOT must be supported/accepted */
  csrr t3, pmpaddr1
  bne  t3, t0, fail2

  /* odd value must also read back unchanged */
  li   t0, 0x20001003
  csrw pmpaddr1, t0
  csrr t3, pmpaddr1
  bne  t3, t0, fail3

  csrw pmpcfg0, zero
  PASS
fail1: FAIL(1)
fail2: FAIL(2)
fail3: FAIL(3)
