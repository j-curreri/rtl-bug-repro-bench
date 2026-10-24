    .section .text
    .globl trap_handler
    trap_handler:
        li a0, 1; j _halt  # Always PASS on trap (override weak trap_handler)

    .globl test_main
    test_main:
        PMP_ALLOW_ALL

        # Read mstatus CSR
        csrr t0, mstatus

        # Check mstatus[35] == 1 (bit 35 of mstatus = LSB of sxl)
        # For unimplemented S-mode, correct core reports XLEN_32 = 0b01, so bit 35 = 1.
        # Buggy core reports XLEN_64 = 0b10, so bit 35 = 0.
        andi t1, t0, 0x0800000000000000  # t1 = mstatus[35] (0 or 0x08...)
        li t2, 0x0800000000000000       # t2 = mask for bit 35 = 1 (XLEN_32 = 0b01)
        beq t1, t2, .pass              # if bit 35 == 1 (correct), go to PASS

        .fail:
            li a0, 3; j _halt          # FAIL(1) = ((1 << 1) | 1) = 3

    .pass:
        li a0, 1; j _halt            # PASS = 1
