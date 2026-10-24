#include "test.h"

/* Spec: ecall must leave mtval = 0; ebreak must leave mtval = 0 or the pc. */
.text
.option norvc
.globl test_main
test_main:
    li s1, -1
    csrw mtval, s1
ecall_pc:
    ecall
    csrr t0, mcause
    li t1, 11
    bne t0, t1, fail1
    csrr t0, mtval
    bnez t0, fail2

    csrw mtval, s1
ebreak_pc:
    ebreak
    csrr t0, mcause
    li t1, 3
    bne t0, t1, fail3
    csrr t0, mtval
    beqz t0, ok
    la t1, ebreak_pc
    bne t0, t1, fail4
ok:
    PASS
fail1: FAIL(1)
fail2: FAIL(2)
fail3: FAIL(3)
fail4: FAIL(4)

.align 4
.globl trap_handler
trap_handler:
    csrr t2, mepc
    addi t2, t2, 4
    csrw mepc, t2
    mret
