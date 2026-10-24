.text
.global _start
.global trap_handler

# PMP setup - allow all memory access
li t0, -1
csrw pmpaddr0, t0
li t0, 0x1f
csrw pmpcfg0, t0

# Cause a breakpoint exception
ebreak

# Return to normal execution after ebreak
j _continue

trap_handler:
    # Set mepc back to _continue
    la t0, _continue
    csrw mepc, t0
    # Clear mcause
    li t0, 0
    csrw mcause, t0
    # Return from exception
    mret

_continue:
    # Read mtval
    csrr t0, mtval
    # Compare with 0 - if mtval == 0, buggy core; if mtval != 0, correct core
    li t1, 0
    cmp t0, t1
    beq zero, _fail  # mtval == 0 -> FAIL (buggy core)
    j _pass          # mtval != 0 -> PASS (correct core)

_fail:
    li a0, 3        # FAIL(1) = (1 << 1) | 1
    j _halt

_pass:
    li a0, 1        # PASS
    j _halt

_halt:
    # Infinite loop - simulator should detect a0 == 1 or a0 == 3 and stop
    j _halt
