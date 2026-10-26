/* Reproducer: menvcfg.CBIE (bits 5:4) is WARL. Value 2'b10 is reserved, so the
 * core must not let it be read back. The buggy RTL stores CBIE_RSVD (2'b10) from
 * csr_wdata[5:4] in csr_regfile.sv (CSR_MENVCFG write, default case) and returns it
 * on read. Correct cores either keep the previous legal value or legalize it. */
#include "test.h"

    .section .text
    .globl test_main
test_main:
    /* Start from a known legal state: CBIE = 2'b11 (reset value). */
    li      t0, 0x30
    csrw    menvcfg, t0

    /* Write the reserved encoding CBIE = 2'b10. */
    li      t0, 0x20
    csrw    menvcfg, t0

    /* Read back and check the CBIE field is not the reserved value. */
    csrr    t1, menvcfg
    srli    t1, t1, 4
    andi    t1, t1, 3
    li      t2, 2
    beq     t1, t2, 1f
    PASS
1:
    FAIL(1)
