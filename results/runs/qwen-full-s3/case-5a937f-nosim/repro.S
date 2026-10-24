#include "test.h"

/* Reproducer for: menvcfg/senvcfg CBIE WARL violation.
 *
 * The CBIE field (bits [5:4]) of menvcfg (and senvcfg/henvcfg) is a WARL
 * field: 2'b00 (illegal), 2'b01 (flush) and 2'b11 (invalidate) are the
 * valid encodings and 2'b10 is reserved.  The RISC-V spec requires that a
 * read of a WARL field never returns a reserved encoding.
 *
 * On this core, writing 2'b10 into the CBIE field makes the CSR write
 * logic latch CBIE_RSVD in the register file (the 'default' arm of the
 * case on menvcfg[5:4]/senvcfg[5:4] in csr_regfile.sv), and the read
 * data path returns the raw two-bit value.  Hence, after such a write,
 * `csrr menvcfg` / `csrr senvcfg` read back [5:4] == 2'b10.
 *
 * This configuration (cv64a6_imafdc_sv39_hpdcache) does not implement
 * the H extension, so henvcfg is not accessible; menvcfg and senvcfg are
 * tested instead.  For each of them, and for each of the four two-bit
 * encodings: keep the remaining bits as read, write the encoding into
 * [5:4], read it back, and fail if the field reads back the reserved
 * 2'b10.  A spec-compliant core passes: it may clamp a reserved write to
 * any valid encoding (or ignore it), but it must never read back 2'b10.
 */

/* Write encoding ENC (0..3) into [5:4] of CSRNUM, keeping the other bits,
 * then read it back; if [5:4] reads the reserved 2'b10, end FAIL(FAILCODE). */
.macro cbie_check ENC CSRNUM FAILCODE
    csrr a1, \CSRNUM               /* current value */
    li   a2, 0x30                  /* CBIE mask */
    xori a2, a2, -1                /* ~0x30 */
    and  a1, a1, a2                /* clear [5:4] */
    li   a2, (\ENC << 4)
    or   a1, a1, a2                /* set [5:4] = ENC */
    csrw \CSRNUM, a1
    csrr a0, \CSRNUM               /* read back */
    andi a0, a0, 0x30
    li   a2, 0x20                  /* reserved encoding in [5:4] */
    beq  a0, a2, bad\@
    j    done\@
bad\@:
    li   a0, (\FAILCODE << 1) | 1
    j    _halt
done\@:
.endm

  .globl test_main
test_main:
  PMP_ALLOW_ALL

  cbie_check 0 0x30a 1
  cbie_check 1 0x30a 1
  cbie_check 2 0x30a 1
  cbie_check 3 0x30a 1

  cbie_check 0 0x10a 2
  cbie_check 1 0x10a 2
  cbie_check 2 0x10a 2
  cbie_check 3 0x10a 2

  PASS

  /* Any unexpected trap -> fail. */
  .globl trap_handler
  .align 2
trap_handler:
  csrr t5, mcause
  FAIL(130)
