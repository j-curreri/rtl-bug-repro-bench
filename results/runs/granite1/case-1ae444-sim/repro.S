    #include "test.h"

    .section .text
    .globl trap_handler
    .align 2
    trap_handler:
        csrr t0, mtval
        beqz t0, .pass
        j .fail

        .pass:
        li a0, 1
        j _halt

        .fail:
        li a0, 2
        j _halt

    .section .text
    .globl test_main
    .align 2
    test_main:
        PMP_ALLOW_ALL
        la t0, trap_handler
        csrw mtvec, t0
        li t1, 0x1
        csrw mie, t1
        li t2, 1000000000
        .loop:
        addi t2, t2, -1
        bne t2, 0, .loop
