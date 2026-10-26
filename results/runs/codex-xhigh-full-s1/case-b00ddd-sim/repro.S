#include "hyp.h"

    .section .text
    .option norvc
    .balign 4
    .globl test_main
test_main:
    /* Route the guest's illegal-instruction exception directly to M-mode. */
    csrw mie, zero
    csrw medeleg, zero
    li t0, (1 << 3)             /* mstatus.MIE */
    csrc mstatus, t0
    PMP_ALLOW_ALL

    /* Both translation stages are Bare: guest PC equals physical PC. */
    csrw satp, zero
    csrw vsatp, zero
    csrw hgatp, zero
    ENTER_VS(guest_illegal)

    .balign 4
guest_illegal:
    /* Custom-0 is unsupported by this core and its example coprocessor.
     * The decoder offloads it through CV-X-IF, which rejects it as illegal.
     */
    .word 0x0000000b
    ecall                       /* Fail if the illegal instruction retires. */
1:  j 1b

    .balign 4
    .globl trap_handler
trap_handler:
    csrr t0, mcause
    li t1, 2                    /* Illegal instruction, not an interrupt. */
    bne t0, t1, unexpected_trap
    csrr t0, mepc
    la t1, guest_illegal
    bne t0, t1, unexpected_trap

    /* Prove that the trapped instruction actually ran in VS-mode. */
    csrr t2, mstatus
    li t1, MSTATUS_MPV
    and t0, t2, t1
    beqz t0, wrong_origin
    srli t0, t2, 11
    andi t0, t0, 3
    li t1, 1                    /* MPP = S, MPV = 1 means VS. */
    bne t0, t1, wrong_origin

    /* mtval for an illegal instruction is zero or instruction bits, never
     * a guest virtual address. Consequently mstatus.GVA must be clear.
     */
    li t1, MSTATUS_GVA
    and t0, t2, t1
    bnez t0, bad_gva
    PASS

unexpected_trap:
    FAIL(1)
wrong_origin:
    FAIL(2)
bad_gva:
    FAIL(3)
