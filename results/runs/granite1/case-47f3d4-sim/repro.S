# Reproducer for RISC-V core bug: mstatus reports XLEN for unimplemented S-mode
# Correct core: sxl = Off (2'b00), reports read-only zero for XLEN control field
# Buggy core: sxl != Off (e.g., XLEN_64 = 2'b10)
# PASS on correct core, FAIL(1) on buggy core

#include "test.h"

.globl test_main
test_main:
    csrr t0, mstatus        # read mstatus CSR
    srli t1, t0, 34        # t1 = mstatus >> 34, t1[1:0] = sxl field
    li t2, 3                # mask = 0b11
    and t1, t1, t2         # t1 = sxl (2 bits)
    li t3, 0                # Off = 0b00
    beq t1, t3, .Lpass    # if sxl == Off, pass
    FAIL(1)                 # else fail
.Lpass:
    PASS
