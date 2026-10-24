    .global _start
    .section .text
_start:
    .cfi_startproc

    PMP_ALLOW_ALL

    // Enable SV39 mode — satp = 0x8000_0000 (mode=8 << 60), PPN=0
    li t0, 0x8000_0000
    csrw satp, t0

    // Set M-mode with mprv=1 (mpv=1 for M-mode entry)
    li t0, (3 << 11)
    csrc mstatus, t0

    // Write to DRAM at 0x8000_0010
    la t0, test_data
    li t1, 0x10
    add t0, t0, t1
    li t2, 0xdeadbeef
    sw t2, 0(t0)

    // MRET to S-mode
    ENTER_MODE(1, after_mret)

    after_mret:
    // Read back DRAM at 0x8000_0010
    la t0, test_data
    li t1, 0x10
    add t0, t0, t1
    lw t2, 0(t0)
    li t3, 0xdeadbeef
    beq t2, t3, pass  // PASS if equal
    li a0, 2; FAIL(1)  // FAIL if not equal

    pass:
    li a0, 1; j _halt

    .cfi_endproc

test_data:
    .word 0
