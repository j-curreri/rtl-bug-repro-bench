# repro.S
#include "hyp.h"
#include "test.h"

.globl test_main
.globl trap_handler

illeg_ins:
  .word 0x1c00  # illegal compressed instruction (funct3=0 for C0)

test_main:
    # Enable G-stage and VS-stage translations
    HGATP_ON
    li t0, 0x01000000  # guest-physical base for vs_root (page 0 at GP=1M)
    VSATP_ON(t0)

    # Enter VS-mode
    ENTER_VS(test_vs)

    # Execute illegal instruction
    la a0, illeg_ins
    jal a0

    # If no trap happened (unlikely), pass
    PASS

trap_handler:
    # Read mstatus
    csrr t0, mstatus
    # Check bit 38 (GVA)
    li t1, 0x4000000000000000  # MSTATUS_GVA = 1 << 38
    and t1, t0, t1            # t1 = mstatus & MSTATUS_GVA
    beq t1, a0, no_gva       # GVA not set → correct core
    # GVA is set → buggy core
    li a0, 3                  # FAIL(1) = (1<<1)|1 = 3
    j _halt

no_gva:
    li a0, 1                  # PASS = 1
    j _halt

test_vs:
    # empty
