    .globl test_main
    .align 2

test_main:
    // Allow all in M-mode with PMP_ALLOW_ALL
    li t0, -1
    csrw pmpaddr0, t0
    li t0, 0x1f
    csrw pmpcfg0, t0

    // Write pmpaddr1 with bit 0 set (odd address), e.g., 0x10001
    li t0, 0x10001
    csrw pmpaddr1, t0

    // Write pmpcfg1 for TOR mode + RWX
    // addr_mode = TOR (01), access_type = RWX (111), locked=0, reserved=0
    // packed: {locked=0, reserved=0, addr_mode=01, access=111} = 0x07
    li t0, 0x07
    csrw pmpcfg1, t0

    // Set up my trap handler
    la t0, my_trap_handler
    csrw mtvec, t0

    // Enter U-mode using ENTER_MODE-like instructions
    li t0, 0x3000      // (3 << 11) for machine mode bits
    csrw mstatus, t0
    li t1, 0x0         // (0 << 11) for U-mode privilege
    csrs mstatus, t1
    la t0, u_label
    csrw mepc, t0
    mret

    // If we return from U-mode (access succeeded), bug is present → call FAIL
    li a0, 3  // FAIL(1) = (1<<1)|1 = 3
    j _halt

my_trap_handler:
    csrr t0, mcause
    li t1, 5  // LD_ACCESS_FAULT = 5
    beq t0, t1, correct_fault
    li a0, 3  // FAIL(1)
    j _halt

correct_fault:
    li a0, 1  // PASS
    j _halt

u_label:
    // U-mode: read boundary 0x1000
    la t0, boundary_val
    lw t0, 0(t0)  // try read — if bug present, this succeeds
    li a0, 3  // FAIL(1) — if access succeeds (buggy core), call FAIL
    j _halt

boundary_val:
    .quad 0x12345678
