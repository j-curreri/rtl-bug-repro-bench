/* repro.S -- reproducer for the CVA6 menvcfg/senvcfg CBIE WARL bug.
 *
 * The RISC-V privileged spec makes the CBIE field (bits [5:4]) of
 * menvcfg/senvcfg/henvcfg a WARL field: 2'b00, 2'b01 and 2'b11 are legal
 * encodings while 2'b10 is reserved and must never be read back, whatever
 * value software wrote.
 *
 * This core's CSR write path (csr_regfile.sv) maps a written value of
 * 2'b10 into its internal CBIE_RSVD state, so a subsequent read of
 * menvcfg/senvcfg returns bits[5:4] = 2'b10, a reserved encoding.
 *
 * The program below writes the reserved encoding 2'b10 to menvcfg.CBIE and
 * senvcfg.CBIE (henvcfg is not implemented in this configuration, RVH=0)
 * and verifies that the field does not read the reserved value back.
 *
 *   - on a spec-compliant (fixed) core: the field keeps a legal encoding
 *     and the program ends with PASS
 *   - on the buggy core: bits [5:4] read back as 2'b10 and the program
 *     ends with FAIL(1) or FAIL(2); any unexpected trap ends with FAIL
 */
#include "test.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  li   t2, 0x20        /* reserved CBIE encoding 2'b10 placed in bits [5:4] */

  /* ---- menvcfg (0x30A): CBIE must never read back 2'b10 ---- */
  csrr t0, menvcfg     /* sanity: field holds a legal value at reset */
  andi t1, t0, 0x30
  beq  t1, t2, fail_menvcfg
  li   t0, 0x20        /* write CBIE = 2'b10 (reserved), all else clear */
  csrw menvcfg, t0
  csrr t0, menvcfg     /* WARL: the read-back must not be the reserved value */
  andi t1, t0, 0x30
  beq  t1, t2, fail_menvcfg
  j    .Ltest_senvcfg

fail_menvcfg:
  FAIL(1)

.Ltest_senvcfg:
  /* ---- senvcfg (0x10A): same rule ---- */
  csrr t0, senvcfg     /* sanity: field holds a legal value at reset */
  andi t1, t0, 0x30
  beq  t1, t2, fail_senvcfg
  li   t0, 0x20        /* write CBIE = 2'b10 (reserved), all else clear */
  csrw senvcfg, t0
  csrr t0, senvcfg     /* WARL: the read-back must not be the reserved value */
  andi t1, t0, 0x30
  beq  t1, t2, fail_senvcfg

  PASS

fail_senvcfg:
  FAIL(2)

/* Any unexpected trap on a correct core means the RTL misbehaves: fail. */
  .globl trap_handler
  .align 2
trap_handler:
  csrr t6, mcause
  FAIL(128)
