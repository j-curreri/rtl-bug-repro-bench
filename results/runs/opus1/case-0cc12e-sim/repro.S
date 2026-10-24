#include "test.h"

/* mtval must be 0 after ECALL, and the PC (or 0) after EBREAK, never the encoding. */
.section .text
.globl test_main
test_main:
    li s1, 0                 /* trap counter */
    csrw mtval, zero

    /* ECALL from M-mode: mtval must be 0 */
    li t1, 0x5a5a
    csrw mtval, t1
    ecall
    li t0, 1
    bne s1, t0, fail1
    li t0, 11
    bne s2, t0, fail2
    bnez s3, fail3

    /* EBREAK: mtval must be 0 or the faulting PC */
    li t1, 0x5a5a
    csrw mtval, t1
.option push
.option norvc
ebrk:
    ebreak
.option pop
    li t0, 2
    bne s1, t0, fail1
    li t0, 3
    bne s2, t0, fail2
    beqz s3, 1f
    la t0, ebrk
    bne s3, t0, fail4
1:
    PASS
fail1: FAIL(1)
fail2: FAIL(2)
fail3: FAIL(3)
fail4: FAIL(4)

.globl trap_handler
.align 2
trap_handler:
    addi s1, s1, 1
    csrr s2, mcause
    csrr s3, mtval
    csrr t0, mepc
    addi t0, t0, 4
    csrw mepc, t0
    mret
