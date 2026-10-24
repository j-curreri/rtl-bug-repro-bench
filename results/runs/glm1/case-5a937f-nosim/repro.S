# repro.S -- menvcfg.CBIE WARL violation: reserved encoding 2'b10 readable
#
# Bug: csrw menvcfg with bits [5:4] == 2'b10 latches riscv::CBIE_RSVD into
#      mcbie_q/scbie_q/hcbie_q (csr_regfile.sv: the write decode maps the
#      reserved encoding through `default:` to CBIE_RSVD instead of snapping
#      it to a legal value). Reading the CSR afterwards returns the reserved
#      encoding, violating the WARL rule for this field.
#
# Spec: menvcfg.CBIE (and its senvcfg/henvcfg counterparts) is WARL.  A write
#       of the reserved encoding 2'b10 must make the field read back as some
#       legal encoding (2'b00 / 2'b01 / 2'b11); it must never be retained.
#
# Test: in M-mode, write 2'b10 into menvcfg[5:4], read the CSR back and fire
#       FAIL if bits [5:4] come back as 2'b10.  Any legal read-back passes.
#       The write occurs with rd = x0, so no register depends on the result.
#
# Note: no trap is expected on either core (M-mode access to menvcfg is
#       allowed and WARL writes do not trap), so the harness' default trap
#       handler stays in place: a surprise trap just FAILs, as it should.

#include "test.h"

#define CSR_MENVCFG 0x30a

    .text
    .globl test_main

test_main:
    # Write the reserved CBIE encoding: value 0b...00_10_0 --> bits [5:4] = 2'b10
    li      t0, 0x20
    csrw    CSR_MENVCFG, t0

    # Read menvcfg back and isolate the CBIE field
    csrr    t1, CSR_MENVCFG
    srli    t1, t1, 4
    andi    t1, t1, 3               # t1 = CBIE as it reads back

    # Reserved encoding retained <=> t1 == 2
    xori    t1, t1, 2               # zero only if the field is 2'b10
    beqz    t1, 1f
    PASS                            # legal encoding (00/01/11): WARL respected
1:
    FAIL(1)                         # reserved encoding readable: WARL violation