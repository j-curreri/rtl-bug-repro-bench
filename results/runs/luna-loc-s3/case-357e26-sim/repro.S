#include "test.h"

    .section .text
    .align 2
    .globl test_main
test_main:
    /* Entry 0: an 8-byte, read-only NAPOT region at protected_word.
       Entry 1: an all-addresses RWX NAPOT region. */
    la      t0, protected_word
    srli    t0, t0, 2
    csrw    pmpaddr0, t0
    li      t0, -1
    csrw    pmpaddr1, t0
    li      t0, 0x1f19
    csrw    pmpcfg0, t0

    la      t0, trap_handler
    csrw    mtvec, t0
    ENTER_MODE(1, supervisor_test)

    .align 2
supervisor_test:
    la      t0, protected_word
    ld      t1, 0(t0)               /* Read permission in entry 0. */
    .globl protected_store
protected_store:
    sd      zero, 0(t0)             /* Must fault: entry 0 is read-only. */
    j       unexpected_return
protected_store_after:
    sd      zero, 8(t0)             /* Outside entry 0; entry 1 allows it. */
    ecall                           /* Return to M-mode for result check. */

unexpected_return:
    ecall

    .align 2
    .globl trap_handler
trap_handler:
    csrr    t0, mcause
    li      t1, 9                   /* S-mode ecall ends the test. */
    beq     t0, t1, check_result
    li      t1, 7                   /* Store/AMO access fault. */
    bne     t0, t1, trap_fail
    csrr    t0, mepc
    la      t1, protected_store
    bne     t0, t1, trap_fail
    la      t0, expected_fault
    li      t1, 1
    sw      t1, 0(t0)
    la      t0, protected_store_after
    csrw    mepc, t0
    mret

trap_fail:
    FAIL(2)

check_result:
    la      t0, expected_fault
    lw      t1, 0(t0)
    li      t2, 1
    bne     t1, t2, fail
    PASS
fail:
    FAIL(3)

    .section .data
    .align 3
protected_word:
    .dword 0x123456789abcdef0
neighbor_word:
    .dword 0
expected_fault:
    .word 0
