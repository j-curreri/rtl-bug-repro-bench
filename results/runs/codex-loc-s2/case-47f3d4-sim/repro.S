#include "test.h"

/* With S-mode absent, mcounteren alone controls U-mode counter access.
 * scounteren does not exist and must not block an enabled counter.
 */
    .section .text
    .balign 4
    .globl test_main
test_main:
    csrw mie, zero
    PMP_ALLOW_ALL
    li t0, 1
    csrw mcounteren, t0
    ENTER_MODE(0, user_test)

user_test:
    csrr s0, cycle
    ecall

    .balign 4
    .globl trap_handler
trap_handler:
    csrr t0, mcause
    li t1, 8                 /* ECALL from U-mode, after the legal read. */
    bne t0, t1, unexpected_trap
    csrr t0, mepc
    la t1, user_test
    addi t1, t1, 4
    bne t0, t1, unexpected_trap
    PASS
unexpected_trap:
    FAIL(1)
