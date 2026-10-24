    .text
    .globl test_main
    .globl trap_handler

    // Simple trap handler that prints FAIL(1) = 3
    trap_handler:
        li a0, 3  // FAIL(1) = (1 << 1) | 1 = 3
        j _halt

    test_main:
        // PMP_ALLOW_ALL
        li t0, -1
        csrw pmpaddr0, t0
        li t0, 0x1f
        csrw pmpcfg0, t0

        // Set MPRV=1, MPV=1 (more privileged than M)
        li t0, 0x0003_0000  // mprv=1, mpv=1 (3 << 11 = 0x0003_0000)
        csrw mstatus, t0

        // ENTER_MODE(1, s_mode) - enter S-mode
        li t0, 0x0003_0000  // (3 << 11) = 0x0003_0000 (clears mprv/mpv)
        csrc mstatus, t0
        li t0, 0x0002_0000  // (1 << 11) for mpp=1 (S-mode)
        csrs mstatus, t0
        la t0, s_mode
        csrw mepc, t0
        mret

    s_mode:
        // Deny PMP access (all addresses)
        li t0, 0xFFFFFFFF
        csrw pmpaddr0, t0
        li t0, 0x00
        csrw pmpcfg0, t0

        // Return to M-mode at after_mret
        la t0, after_mret
        csrw mepc, t0
        mret

    after_mret:
        // Load from DRAM (0x80000000)
        li a0, 0x80000000
        lb a1, 0(a0)

        // PASS on correct core (a0 = 1)
        li a0, 1
        j _halt
