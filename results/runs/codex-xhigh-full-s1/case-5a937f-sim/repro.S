#include "test.h"

/* menvcfg.CBIE occupies bits [5:4]; 0b10 is reserved. */
#define MENVCFG       0x30a
#define CBIE_MASK     0x30
#define CBIE_RESERVED 0x20

    .section .text
    .balign 4
    .globl test_main
test_main:
    /* Preserve other fields while attempting the illegal WARL encoding. */
    csrr t0, MENVCFG
    li   t1, CBIE_MASK
    not  t1, t1
    and  t1, t0, t1
    ori  t1, t1, CBIE_RESERVED
    csrw MENVCFG, t1
    csrr t2, MENVCFG
    csrw MENVCFG, t0

    /* Any legal readback (00, 01, or 11) is acceptable. */
    andi t2, t2, CBIE_MASK
    li   t3, CBIE_RESERVED
    beq  t2, t3, reserved_readback
    PASS

reserved_readback:
    FAIL(1)

    .balign 4
    .globl trap_handler
trap_handler:
    csrr t6, mcause
    FAIL(2)
