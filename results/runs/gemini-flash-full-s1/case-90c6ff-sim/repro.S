#include "hyp.h"

.globl trap_handler
trap_handler:
    csrr t0, mcause
    li t1, 10           # ENV_CALL_VSMODE
    bne t0, t1, 1f
    li t2, 0x1234
    bne a1, t2, 1f
    PASS
1:
    FAIL(1)

.globl test_main
test_main:
    PMP_ALLOW_ALL

    # Map idx=512 (GPA 0x80_0000_0000) to HPA 0x80000000
    GIGA_LEAF(g_root, 512, 0x80000000, G_RWX)

    # Enable G-stage translation (Sv39x4)
    HGATP_ON

    # vsatp = Bare (translation off)
    csrw vsatp, zero

    # Clear a1 so we can verify VS-mode execution
    li a1, 0

    # Set up VS-mode entry (mstatus.MPV=1, mstatus.MPP=S)
    li t0, MSTATUS_MPV
    csrs mstatus, t0
    li t0, (3 << 11)
    csrc mstatus, t0
    li t0, (1 << 11)
    csrs mstatus, t0

    # Compute target GPA = (512 << 30) | (vs_code & 0x3fffffff)
    la t0, vs_code
    li t1, 0x3fffffff
    and t0, t0, t1
    li t2, 512
    slli t2, t2, 30
    or t0, t0, t2
    csrw mepc, t0
    mret

.align 2
vs_code:
    li a1, 0x1234
    ecall

HYP_TABLES
