#include "test.h"

    .section .text
    .balign 4
    .globl test_main
test_main:
    /* All accesses stay in M-mode; hgatp never translates this program. */
    li t0, (1 << 17)             /* mstatus.MPRV */
    csrc mstatus, t0

    /* Learn the implemented VMID/PPN bits using supported Sv39x4 MODE.
     * VMID=1, PPN=0x80004 (16 KiB-aligned root at PA 0x80004000).
     */
    li t0, 0x8000100000080004
    csrw hgatp, t0
    csrr s0, hgatp
    slli s0, s0, 4
    srli s0, s0, 4               /* Ignore MODE[63:60]. */

    /* Establish a distinct old value: VMID=0, root PA=0x80000000. */
    li t0, 0x8000000000080000
    csrw hgatp, t0
    csrr t1, hgatp
    slli t1, t1, 4
    srli t1, t1, 4
    beq t1, s0, setup_failed

    /* MODE=15 is unsupported. Unlike satp, hgatp must still update its
     * other WARL fields. Their requested values are already known legal.
     * The implementation may choose its legal MODE readback freely.
     */
    li t0, 0xf000100000080004
    csrw hgatp, t0
    csrr t1, hgatp
    slli t1, t1, 4
    srli t1, t1, 4
    bne t1, s0, fields_not_updated

    PASS

setup_failed:
    FAIL(1)
fields_not_updated:
    FAIL(2)

    .balign 4
    .globl trap_handler
trap_handler:
    csrr t6, mcause
    FAIL(127)
