#include "test.h"

    .section .text
    .globl test_main
test_main:
    # Write the reserved CBIE encoding 2'b10 (bits [5:4]) to menvcfg.
    li   t0, 0x20
    csrw menvcfg, t0

    # Read back. CBIE is WARL and must never read back the reserved value 2'b10.
    csrr t1, menvcfg
    srli t1, t1, 4
    andi t1, t1, 3
    li   t2, 2
    beq  t1, t2, 1f
    PASS
1:
    FAIL(1)
