.include "harness/test.h"
.include "harness/hyp.h"

.data
.align 14
g_root: .space 16384
.align 12
vs_root: .space 4096

.globl test_vs
test_vs:
    mret

.globl test_main
test_main:
    la t0, trap_handler
    csrw mtvec, t0

    ENTER_VS(test_vs)
    HGATP_ON

    // Map execute-only 1G page at guest physical 0x8000_000000000000
    li t0, 0x8000_000000000000
    li t1, PTE_V | PTE_X
    GIGA_LEAF(g_root, 0, t0, t1)

    // Store value 42 at page offset 0
    li t0, 42
    la t1, 0x8000_000000000000
    sd t0, 0(t1)

    // HLVX read (should succeed on correct core)
    li t1, 0          // guest page number (VPN for 1G = 0)
    li t2, 3          // rs2 = 5'b11 for HLVX_HU (execute-only + load unsigned halfword)
    li t3, 2          // rd
    hlx t3, t1, t2    // HLVX instruction

    // HLV read (should fail on buggy core if the bug exists)
    li t1, 0
    li t2, 1          // rs2 = 5'b1 for HLV_HU (execute-only + load unsigned halfword)
    li t3, 2
    hlv t3, t1, t2    // HLV instruction

    PASS
