#include "test.h"

    .section .text
    .balign 4
    .globl test_main
test_main:
    /* menvcfg.CBIE occupies bits [5:4]. Preserve the other fields. */
    csrr t0, 0x30a
    li t1, -49                  /* ~0x30 */
    and t0, t0, t1
    ori t0, t0, 0x20            /* Reserved CBIE encoding 2'b10. */
    csrw 0x30a, t0

    /* WARL may select any legal encoding, but must never return 10. */
    csrr t0, 0x30a
    andi t0, t0, 0x30
    li t1, 0x20
    beq t0, t1, reserved_cbie
    PASS

reserved_cbie:
    FAIL(1)

    .balign 4
    .globl trap_handler
trap_handler:
    csrr t6, mcause
    FAIL(2)
