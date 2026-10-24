.text
.globl test_main
.type test_main, @function
test_main:
    # PMP_ALLOW_ALL for M-mode
    li t0, -1
    csrw pmpaddr0, t0
    li t0, 0x1f
    csrw pmpcfg0, t0

    # Switch to U-mode
    li t0, (3 << 11)
    csrc mstatus, t0
    li t0, (0 << 11)
    csrs mstatus, t0
    la t0, u_label
    csrw mepc, t0
    mret

    u_label:
        # Write PMP cfg for entry 1 (TOR mode, RW access)
        # addr_mode = 2'b01 (TOR), access = 3'b011 (READ|WRITE), locked = 0
        li t0, 0x011  # [locked=0, reserved=00, addr_mode=01, access=011]
        csrw pmpcfg1, t0

        # Write PMP addr for entry 1 with lowest bit set
        # conf_addr = 0x0101 (lowest bit of conf_addr set), base = 0x0101 << 2 = 0x0404
        li t0, 0x0101
        csrw pmpaddr1, t0

        # Access 0x03FF (inside protected range [0, 0x0400)), should be protected on correct core
        li t1, 0x03FF
        li t2, 42
        sd t2, 0(t1)

        # Read back from 0x03FF
        la t1, 0x03FF
        ld t2, 0(t1)

        # PASS
        li a0, 1
        j _halt
